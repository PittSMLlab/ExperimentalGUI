function runHreflexMwaveMonitorLive(leg, tapSensor, hSensor, options)
%RUNHREFLEXMWAVEMONITORLIVE Live H-reflex M-wave monitor for one leg.
%
%   Reads one leg from the Vicon DataStream, shows each stimulus's M- and
% H-wave amplitudes, and raises an alert when the M-wave has been outside
% its tolerance window for three stimuli in a row. Run one instance per
% leg, each in its OWN MATLAB, separate from the control instance. It
% never opens the Arduino serial port and never writes to a datlog; it
% saves its own log file when it stops.
%
%   RELIABILITY OVER SPEED: a stimulus touching a lost frame is counted as
% invalid and never plotted, and neither adds to nor resets the alert
% count. The status line shows invalid stimuli, lost frames, and how far
% behind the stream the monitor is. Delays are relative to the least-
% delayed frame seen, so they measure falling behind, not the fixed
% transport delay, and a stimulus's delay runs from when its trigger was
% seen (up to one 10 ms frame after the true rising edge).
%
%   Stop it by closing the figure or with Ctrl+C. Either way it
% disconnects and saves the log.
%
%   NOTE: run data the cleanup needs lives in a containers.Map, a handle
% object its onCleanup callback keeps alive. A callback using a nested
% function's shared variables fails, because MATLAB may destroy them
% before onCleanup fires on exit.
%
% Inputs:
%   leg       - char; 'R' or 'L'
%   tapSensor - EMG sensor number of this leg's proximal TA
%   hSensor   - EMG sensor number of this leg's H-reflex muscle
%
% Optional Name-Value Inputs:
%   muscle          - H-reflex muscle label: 'SOL', 'MG', or 'LG'
%                     (default: 'SOL'; display and log only)
%   baselineMwaveMv - baseline M-wave amplitude (mV). Default NaN prompts
%                     the experimenter (PROMPTHREFLEXBASELINE).
%   numConsecutiveForAlert - consecutive out-of-window stimuli that raise
%                     the alert (default: 3)
%   durationS       - stop after this long (s) (default: Inf)
%   outputDir       - folder for the log file (default: '' = current)
%   hostName        - DataStream server (default: 'localhost:801')
%   bufferSize      - frames the SDK client queues (default: 100)
%   source          - source struct shaped like
%                     HREFLEXSOURCEDATASTREAM's output, replacing the
%                     Vicon connection. For tests. (default: [])
%
% Outputs:
%   None (saves HreflexMonitorLive_<leg>_<timestamp>.mat, variable
%   monitorLog)
%
% Toolbox Dependencies:
%   None (external: Vicon DataStream SDK; labTools +Hreflex namespace)
%
% See also HREFLEXSOURCEDATASTREAM, ASSEMBLELIVECHUNK, STEPHREFLEXMONITOR,
%   COMPUTEMWAVEALERT, TRIMMONITORBUFFERS.

arguments
    leg       (1,1) char {mustBeMember(leg, {'R', 'L'})}
    tapSensor (1,1) double {mustBePositive, mustBeInteger}
    hSensor   (1,1) double {mustBePositive, mustBeInteger}
    options.muscle (1,:) char ...
        {mustBeMember(options.muscle, {'SOL', 'MG', 'LG'})} = 'SOL'
    options.baselineMwaveMv (1,1) double = NaN
    options.numConsecutiveForAlert (1,1) double ...
        {mustBePositive, mustBeInteger} = 3
    options.durationS (1,1) double {mustBePositive} = Inf
    options.outputDir char = ''
    options.hostName  (1,:) char = 'localhost:801'
    options.bufferSize (1,1) double {mustBePositive, mustBeInteger} = 100
    options.source = []
end

flushEveryFrames = 100;  % frames; about 1 s between timing-log flushes,
                         % the most a Ctrl+C can lose from that log
trimEveryFrames  = 500;  % frames; about 5 s between buffer trims
uiEveryFrames    = 10;   % frames; about 0.1 s between UI flushes
statusEvery      = 100;  % frames; about 1 s between status updates
flatCheckFrame   = 200;  % frame at which to warn about a flat channel
noFramePauseS    = 0.001; % s; avoids spinning while no frame is queued

legSlot = 1 + strcmpi(leg, 'L');  % 1 = right, 2 = left (+Hreflex slots)

if isnan(options.baselineMwaveMv)
    baselineMwaveMv = hreflexMonitor.promptHreflexBaseline(leg);
else
    baselineMwaveMv = options.baselineMwaveMv;
end
bounds = hreflexMonitor.computeMwaveTolerance(baselineMwaveMv);

%% Open the Source and Figure
% connect after the baseline prompt, so frames do not queue behind it
if isempty(options.source)
    source = hreflexMonitor.hreflexSourceDataStream(leg, tapSensor, ...
        hSensor, 'hostName', options.hostName, ...
        'bufferSize', options.bufferSize);
else
    source = options.source;
end

meta = struct('leg', leg, 'tapSensor', tapSensor, 'hSensor', hSensor, ...
    'muscle', options.muscle, 'baselineMwaveMv', baselineMwaveMv, ...
    'bounds', bounds, 'outputDir', options.outputDir);
runData = containers.Map();
runData('state')       = [];
runData('sourceState') = [];
runData('numFrames')   = 0;
runData('numInvalid')  = 0;
runData('stimDelayS')  = zeros(0, 1);
runData('readMs')      = zeros(0, 1);
runData('behindS')     = zeros(0, 1);
cleanupRun = onCleanup(@() finishRun(source, runData, meta));

handles = hreflexMonitor.createMonitorFigure(leg, options.muscle, ...
    baselineMwaveMv, bounds);

state       = [];
sourceState = [];
numFrames   = 0;
numInvalid  = 0;
readBatch   = nan(flushEveryFrames, 1);
behindBatch = nan(flushEveryFrames, 1);
numInBatch  = 0;
wallMinusStream = Inf;     % s; smallest wall-clock minus stream time seen
tStart = tic;

%% Read and Process Frames Until Stopped
while toc(tStart) < options.durationS
    tRead = tic;
    [hasFrame, frame] = source.readFrame();
    if ~hasFrame
        if ~isvalid(handles.fig)
            break;
        end
        drawnow limitrate;
        pause(noFramePauseS);
        continue;
    end
    readTimeMs = 1000 * toc(tRead);

    [sourceState, chunk] = hreflexMonitor.assembleLiveChunk( ...
        sourceState, frame.frameNum, frame.tap, frame.h, frame.trig, ...
        source.period);
    runData('sourceState') = sourceState;
    if isempty(chunk.times)
        continue;   % a repeated frame adds no data
    end
    [state, newAmps] = hreflexMonitor.stepHreflexMonitor(state, chunk, ...
        options.muscle, legSlot);
    runData('state') = state;

    % log how far this frame's data is behind the fastest frame seen
    lagS = toc(tStart) - chunk.times(end);
    wallMinusStream = min(wallMinusStream, lagS);
    latestBehindS = lagS - wallMinusStream;
    numFrames = numFrames + 1;
    runData('numFrames') = numFrames;
    numInBatch = numInBatch + 1;
    readBatch(numInBatch)   = readTimeMs;
    behindBatch(numInBatch) = latestBehindS;
    if numInBatch == flushEveryFrames
        flushTimingLog(runData, readBatch, behindBatch);
        numInBatch = 0;
    end

    %% Show New Stimuli
    numNew = size(newAmps, 1);
    numInvalidNow = size(state.invalidOnsetTimes, 1);
    if numNew > 0 || numInvalidNow > numInvalid
        numInvalid = numInvalidNow;
        runData('numInvalid') = numInvalid;
        if ~isvalid(handles.fig)
            break;
        end
        hreflexMonitor.updateMonitorFigure(handles, state, bounds, ...
            options.numConsecutiveForAlert);
        setStatus(handles, numInvalid, sourceState, latestBehindS);
        drawnow;
        if numNew > 0
            onsets = state.onsetTimes(end - numNew + 1:end);
            runData('stimDelayS') = [runData('stimDelayS'); ...
                toc(tStart) - wallMinusStream - onsets];
        end
    end

    %% Periodic Housekeeping
    if numFrames == flatCheckFrame
        warnIfFlat(state, tapSensor, hSensor);
    end
    if mod(numFrames, trimEveryFrames) == 0
        state = hreflexMonitor.trimMonitorBuffers(state);
    end
    if mod(numFrames, uiEveryFrames) == 0
        if ~isvalid(handles.fig)
            break;
        end
        if mod(numFrames, statusEvery) == 0
            setStatus(handles, numInvalid, sourceState, latestBehindS);
        end
        drawnow limitrate;
    end
end

flushTimingLog(runData, readBatch(1:numInBatch), ...
    behindBatch(1:numInBatch));

end

%% Local Functions

function flushTimingLog(runData, readNew, behindNew)
%FLUSHTIMINGLOG Append a batch of per-frame timing to the run log.
%
%   Batched because appending copies the whole array, which would be too
% slow to repeat on every frame of a long run.
%
% Inputs:
%   runData   - containers.Map of run data
%   readNew   - numNew x 1 frame read times (ms)
%   behindNew - numNew x 1 seconds behind the stream
%
% Outputs:
%   None (updates runData, a handle object)
%
% Toolbox Dependencies:
%   None

maxLogFrames = 360000;   % frames; 1 hour at 100 Hz, then logging stops

if numel(runData('readMs')) + numel(readNew) <= maxLogFrames
    runData('readMs')  = [runData('readMs'); readNew];
    runData('behindS') = [runData('behindS'); behindNew];
end

end

function setStatus(handles, numInvalid, sourceState, behindS)
%SETSTATUS Show invalid stimuli, lost frames, and current delay.
%
% Inputs:
%   handles     - struct from CREATEMONITORFIGURE
%   numInvalid  - invalid stimuli so far
%   sourceState - running state from ASSEMBLELIVECHUNK
%   behindS     - seconds behind the stream
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None

set(handles.status, 'String', sprintf( ...
    'Invalid stims: %d | Lost frames: %d | Behind: %.2f s', ...
    numInvalid, sourceState.numLostFrames, behindS));

end

function warnIfFlat(state, tapSensor, hSensor)
%WARNIFFLAT Warn once if a sensor looks switched off or misnumbered.
%
% Inputs:
%   state     - running state from STEPHREFLEXMONITOR
%   tapSensor - EMG sensor number of the proximal TA
%   hSensor   - EMG sensor number of the H-reflex muscle
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None

if ~(std(state.detect.tap, 'omitnan') > 0)
    warning('runHreflexMwaveMonitorLive:flatTA', ...
        'TA channel (sensor %d) is flat. Is the sensor on?', tapSensor);
end
if ~(std(state.hBuf, 'omitnan') > 0)
    warning('runHreflexMwaveMonitorLive:flatH', ...
        'H-muscle channel (sensor %d) is flat. Is the sensor on?', hSensor);
end

end

function finishRun(source, runData, meta)
%FINISHRUN Disconnect and save the log, including after Ctrl+C or error.
%
% Inputs:
%   source  - source struct, with a close handle
%   runData - containers.Map of run data
%   meta    - struct of run settings: leg, tapSensor, hSensor, muscle,
%             baselineMwaveMv, bounds, outputDir
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None

source.close();

state       = runData('state');
sourceState = runData('sourceState');
numFrames   = runData('numFrames');
stimDelayS  = runData('stimDelayS');
readMs      = runData('readMs');
behindS     = runData('behindS');

monitorLog.leg             = meta.leg;
monitorLog.tapSensor       = meta.tapSensor;
monitorLog.hSensor         = meta.hSensor;
monitorLog.muscle          = meta.muscle;
monitorLog.baselineMwaveMv = meta.baselineMwaveMv;
monitorLog.bounds          = meta.bounds;
monitorLog.sourceState     = sourceState;
monitorLog.readMs          = readMs;
monitorLog.behindS         = behindS;
monitorLog.stimDelayS      = stimDelayS;
if ~isempty(state)
    monitorLog.onsetTimes        = state.onsetTimes;
    monitorLog.amps              = state.amps;
    monitorLog.snippets          = state.snippets;
    monitorLog.mWaveInds         = state.mWaveInds;
    monitorLog.invalidOnsetTimes = state.invalidOnsetTimes;
end

outputDir = meta.outputDir;
if isempty(outputDir)
    outputDir = pwd;
end
logPath = fullfile(outputDir, sprintf('HreflexMonitorLive_%s_%s.mat', ...
    meta.leg, char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
save(logPath, 'monitorLog');

fprintf('Frames: %d; ', numFrames);
if ~isempty(sourceState)
    fprintf('lost: %d; repeated: %d; restarts: %d\n', ...
        sourceState.numLostFrames, sourceState.numRepeatedFrames, ...
        sourceState.numRestarts);
else
    fprintf('no frames were read\n');
end
fprintf('Stimuli: %d valid, %d invalid\n', numel(stimDelayS), ...
    runData('numInvalid'));
if ~isempty(stimDelayS)
    fprintf(['Stimulus-to-display delay (s): median %.3f, ' ...
        'max %.3f\n'], median(stimDelayS), max(stimDelayS));
end
if ~isempty(readMs)
    fprintf('Read (ms): median %.2f, max %.2f; max behind: %.3f s\n', ...
        median(readMs), max(readMs), max(behindS));
end
fprintf('Log saved: %s\n', logPath);

end
