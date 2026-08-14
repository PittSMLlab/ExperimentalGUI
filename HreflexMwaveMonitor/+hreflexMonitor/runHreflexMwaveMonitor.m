function runHreflexMwaveMonitor(trial,leg,options)
%RUNHREFLEXMWAVEMONITOR Live/replay near-real-time H-reflex M-wave
%monitor.
%
%   Phase 1 (single leg, one EMG muscle) replayed a previously collected
%   trial (TRIAL, from HREFLEXSOURCEREPLAYC3D) through the online
%   pipeline (DETECTSTIMARTIFACTONLINE, STEPHREFLEXMONITOR), updating
%   one persistent figure on each newly detected stimulus. Phase 2 adds
%   a second axes plotting M-wave amplitude vs. stimulus number, with
%   a prompt-entered per-leg baseline and +-10% tolerance bounds
%   (COMPUTEMWAVETOLERANCE) so the experimenter can see at a glance
%   whether the DS8R current needs adjusting, plus an out-of-tolerance
%   indicator and a last-N-stimuli-out-of-tolerance counter. A later
%   phase adds a second leg and a live Vicon DataStream source; the
%   replay loop below is the only part expected to change.
%
%   ±10% BOUNDS ARE NOT DRAWN ON THE SNIPPET AXES: M-wave amplitude is
%   a peak-to-peak difference (mV), not a raw EMG voltage (V) sample --
%   a horizontal line at "baseline ± 10%" would not correspond to
%   anything on that trace. The bounds instead live on the new trend
%   axes, whose y-axis IS M-wave amplitude.
%
%   Chunking TRIAL's full arrays into CHUNKSIZE-sample blocks simulates
%   the cadence the live Vicon DataStream delivers analog subsamples
%   (about 10-20 samples per Vicon frame at 2 kHz EMG / 100 Hz frames);
%   it is NOT wall-clock-paced, so replay runs as fast as the figure
%   can redraw. Both axes' plotted objects are created ONCE and updated
%   in place via set(...) + drawnow limitrate on each new stimulus --
%   never replotted or reopened -- to keep per-update work bounded and
%   jitter-free (same principle as
%   NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO's reusable animatedline
%   markers).
%
% Inputs:
%   trial - struct from HREFLEXSOURCEREPLAYC3D (Phase 1 replay source)
%   leg   - char; 'R' or 'L' -- which leg to monitor. TEMPORARY: Phase
%           1-2 are single-leg only; Phase 3 removes this argument and
%           monitors both legs simultaneously (one figure each)
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
%   numRecentForCounter - number of most-recent stimuli the "out of
%                     tolerance" counter considers (default: 10)
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None (external: BTK via HREFLEXSOURCEREPLAYC3D; labTools +Hreflex
%   namespace via STEPHREFLEXMONITOR)
%
% See also HREFLEXSOURCEREPLAYC3D, STEPHREFLEXMONITOR,
%   DETECTSTIMARTIFACTONLINE, COMPUTEMWAVETOLERANCE,
%   PROMPTHREFLEXBASELINE.

arguments
    trial (1,1) struct
    leg   (1,1) char {mustBeMember(leg,{'R','L'})}
    options.chunkSize (1,1) double ...
        {mustBePositive,mustBeInteger} = 10
    options.baselineMwaveMv (1,1) double = NaN
    options.numRecentForCounter (1,1) double ...
        {mustBePositive,mustBeInteger} = 10
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
fig = figure('Name',sprintf('H-Reflex M-Wave Monitor (%s, %s)', ...
    leg,trial.muscle),'NumberTitle','off');

axSnippet = subplot(2,1,1,'Parent',fig);
hold(axSnippet,'on');
% snippet time axis: -5 ms to +55 ms around the artifact peak (121
% samples @ 2 kHz), matches HREFLEX.EXTRACTSNIPPETS
timesSnippetMs = 1000 * (-0.005:0.0005:0.055);
hSnippetLine = plot(axSnippet,timesSnippetMs,nan(1,121), ...
    'Color',[0 0.45 0.74]);
hMwaveMarker = plot(axSnippet,nan(1,2),nan(1,2),'ro-', ...
    'LineWidth',1.5,'MarkerFaceColor','r');
xlabel(axSnippet,'Time Relative to Stim Artifact (ms)');
ylabel(axSnippet,'EMG (V)');
titleHandle = title(axSnippet,'Waiting for first stimulus...');
grid(axSnippet,'on');

axTrend = subplot(2,1,2,'Parent',fig);
hold(axTrend,'on');
hTrendLine = plot(axTrend,nan,nan,'o-','Color',[0 0.45 0.74], ...
    'MarkerFaceColor',[0 0.45 0.74]);
yline(axTrend,bounds(1),'r--','LineWidth',1);
yline(axTrend,bounds(2),'r--','LineWidth',1);
yline(axTrend,baselineMwaveMv,'k:','LineWidth',1);
xlabel(axTrend,'Stimulus #');
ylabel(axTrend,'M-Wave Amplitude (mV)');
indicatorHandle = title(axTrend,'','FontWeight','bold');
counterHandle = text(axTrend,0.02,0.92,'','Units','normalized');
grid(axTrend,'on');

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

    latestSnippet = state.snippets(end,:);
    markerInds = state.mWaveInds(end,:);   % [indMin indMax]

    set(hSnippetLine,'YData',latestSnippet);
    set(hMwaveMarker,'XData',timesSnippetMs(markerInds), ...
        'YData',latestSnippet(markerInds));

    numStim = size(state.amps,1);
    mWaveTrend = state.amps(:,1);
    set(hTrendLine,'XData',1:numStim,'YData',mWaveTrend);

    [~,isWithinTol] = ...
        hreflexMonitor.computeMwaveTolerance(baselineMwaveMv,mWaveTrend);
    recentWindow = max(1,numStim - options.numRecentForCounter + 1):numStim;
    numOutRecent = sum(~isWithinTol(recentWindow));

    set(titleHandle,'String',sprintf( ...
        'Stim #%d - M-wave: %.3f mV',numStim,mWaveTrend(end)));
    if isWithinTol(end)
        set(indicatorHandle,'String','IN TOLERANCE','Color',[0 0.5 0]);
    else
        set(indicatorHandle,'String','OUT OF TOLERANCE','Color','r');
    end
    set(counterHandle,'String',sprintf( ...
        '%d/%d of last %d out of tolerance', ...
        numOutRecent,numel(recentWindow),options.numRecentForCounter));
    drawnow limitrate;
end

end
