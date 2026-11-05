function runHreflexMwaveMonitor(trial,leg,options)
%RUNHREFLEXMWAVEMONITOR Replay a trial through the M-wave monitor.
%
%   Replays a previously collected trial (TRIAL, from
%   HREFLEXSOURCEREPLAYC3D) through the online pipeline
%   (DETECTSTIMARTIFACTONLINE, STEPHREFLEXMONITOR), updating the same
%   figure the live monitor uses (CREATEMONITORFIGURE,
%   UPDATEMONITORFIGURE) on each newly detected stimulus: the latest
%   snippet, M- and H-wave trends with the baseline and +-10% tolerance
%   bounds (COMPUTEMWAVETOLERANCE), and the consecutive out-of-window
%   alert (COMPUTEMWAVEALERT). For live use, see
%   RUNHREFLEXMWAVEMONITORLIVE.
%
%   Chunking TRIAL's full arrays into CHUNKSIZE-sample blocks simulates
%   the cadence the live Vicon DataStream delivers analog subsamples
%   (20 samples per Vicon frame at 2 kHz EMG / 100 Hz frames); it is NOT
%   wall-clock-paced, so replay runs as fast as the figure can redraw.
%
% Inputs:
%   trial - struct from HREFLEXSOURCEREPLAYC3D
%   leg   - char; 'R' or 'L' -- which leg to monitor
%
% Optional Name-Value Inputs:
%   chunkSize       - samples per simulated acquisition pull (default:
%                     10, matches a typical Vicon analog-subsample
%                     block)
%   baselineMwaveMv - scalar; per-leg baseline M-wave amplitude (mV)
%                     for the tolerance band. Default NaN prompts the
%                     experimenter (PROMPTHREFLEXBASELINE); pass an
%                     explicit value to skip the prompt (e.g. for
%                     automated tests).
%   numConsecutiveForAlert - consecutive out-of-window stimuli that
%                     raise the alert (default: 3)
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None (external: BTK via HREFLEXSOURCEREPLAYC3D; labTools +Hreflex
%   namespace via STEPHREFLEXMONITOR)
%
% See also HREFLEXSOURCEREPLAYC3D, STEPHREFLEXMONITOR,
%   RUNHREFLEXMWAVEMONITORLIVE, CREATEMONITORFIGURE, UPDATEMONITORFIGURE,
%   COMPUTEMWAVEALERT, COMPUTEMWAVETOLERANCE, PROMPTHREFLEXBASELINE.

arguments
    trial (1,1) struct
    leg   (1,1) char {mustBeMember(leg,{'R','L'})}
    options.chunkSize (1,1) double ...
        {mustBePositive,mustBeInteger} = 10
    options.baselineMwaveMv (1,1) double = NaN
    options.numConsecutiveForAlert (1,1) double ...
        {mustBePositive,mustBeInteger} = 3
end

legSlot = 1 + strcmpi(leg,'L');  % 1 = right, 2 = left (+Hreflex convention)
if legSlot == 1
    trigAll = trial.trigR;  tapAll = trial.tapR;  hAll = trial.hR;
else
    trigAll = trial.trigL;  tapAll = trial.tapL;  hAll = trial.hL;
end

if isnan(options.baselineMwaveMv)
    baselineMwaveMv = hreflexMonitor.promptHreflexBaseline(leg);
else
    baselineMwaveMv = options.baselineMwaveMv;
end
bounds = hreflexMonitor.computeMwaveTolerance(baselineMwaveMv);

%% Set Up the Persistent Figure (Created Once; Updated In Place)
handles = hreflexMonitor.createMonitorFigure(leg,trial.muscle, ...
    baselineMwaveMv,bounds);

%% Replay the Trial Through the Online Pipeline
state = [];
numSamps = numel(trigAll);
for startInd = 1:options.chunkSize:numSamps
    endInd = min(startInd + options.chunkSize - 1,numSamps);
    chunk.times = trial.times(startInd:endInd);
    chunk.trig  = trigAll(startInd:endInd);
    chunk.tap   = tapAll(startInd:endInd);
    chunk.h     = hAll(startInd:endInd);

    [state,newAmps] = hreflexMonitor.stepHreflexMonitor( ...
        state,chunk,trial.muscle,legSlot);

    if isempty(newAmps)
        continue;
    end

    hreflexMonitor.updateMonitorFigure(handles,state,bounds, ...
        options.numConsecutiveForAlert);
    drawnow limitrate;
end

end
