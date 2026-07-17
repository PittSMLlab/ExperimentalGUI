function runHreflexMwaveMonitor(trial,leg,options)
%RUNHREFLEXMWAVEMONITOR Live/replay near-real-time H-reflex M-wave
%monitor.
%
%   Phase 1 MVP: single leg, one EMG muscle. Replays a previously
%   collected trial (TRIAL, from HREFLEXSOURCEREPLAYC3D) through the
%   same online pipeline (DETECTSTIMARTIFACTONLINE, STEPHREFLEXMONITOR)
%   the live tool will use, updating one persistent figure on each
%   newly detected stimulus: the H-reflex EMG snippet with the M-wave
%   window highlighted. A later phase adds the +-10% tolerance bounds,
%   the out-of-tolerance indicator/counter, a second leg, and a live
%   Vicon DataStream source; the replay loop below is the only part
%   expected to change (the figure setup and the per-chunk
%   STEPHREFLEXMONITOR call are already Phase 3-ready).
%
%   Chunking TRIAL's full arrays into CHUNKSIZE-sample blocks simulates
%   the cadence the live Vicon DataStream delivers analog subsamples
%   (about 10-20 samples per Vicon frame at 2 kHz EMG / 100 Hz frames);
%   it is NOT wall-clock-paced, so replay runs as fast as the figure
%   can redraw. The figure, snippet line, and M-wave markers are
%   created ONCE and updated in place via set(...) + drawnow limitrate
%   on each new stimulus -- never replotted or reopened -- to keep
%   per-update work bounded and jitter-free (same principle as
%   NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO's reusable animatedline
%   markers).
%
% Inputs:
%   trial - struct from HREFLEXSOURCEREPLAYC3D (Phase 1 replay source)
%   leg   - char; 'R' or 'L' -- which leg to monitor. TEMPORARY: Phase
%           1 is single-leg only; Phase 3 removes this argument and
%           monitors both legs simultaneously (one figure each)
%
% Optional Name-Value Inputs:
%   chunkSize - samples per simulated acquisition pull (default: 10,
%               matches a typical Vicon analog-subsample block)
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None (external: BTK via HREFLEXSOURCEREPLAYC3D; labTools +Hreflex
%   namespace via STEPHREFLEXMONITOR)
%
% See also HREFLEXSOURCEREPLAYC3D, STEPHREFLEXMONITOR,
%   DETECTSTIMARTIFACTONLINE.

arguments
    trial (1,1) struct
    leg   (1,1) char {mustBeMember(leg,{'R','L'})}
    options.chunkSize (1,1) double ...
        {mustBePositive,mustBeInteger} = 10
end

legSlot = 1 + strcmpi(leg,'L');  % 1 = right, 2 = left (+Hreflex convention)
if legSlot == 1
    trigAll = trial.trigR;  tapAll = trial.tapR;  hAll = trial.hR;
else
    trigAll = trial.trigL;  tapAll = trial.tapL;  hAll = trial.hL;
end

%% Set Up the Persistent Figure (Created Once; Updated In Place)
fig = figure('Name',sprintf('H-Reflex M-Wave Monitor (%s, %s)', ...
    leg,trial.muscle),'NumberTitle','off');
ax = axes(fig);
hold(ax,'on');
% snippet time axis: -5 ms to +55 ms around the artifact peak (121
% samples @ 2 kHz), matches HREFLEX.EXTRACTSNIPPETS
timesSnippetMs = 1000 * (-0.005:0.0005:0.055);
hSnippetLine = plot(ax,timesSnippetMs,nan(1,121),'Color',[0 0.45 0.74]);
hMwaveMarker = plot(ax,nan(1,2),nan(1,2),'ro-','LineWidth',1.5, ...
    'MarkerFaceColor','r');
xlabel(ax,'Time Relative to Stim Artifact (ms)');
ylabel(ax,'EMG (V)');
titleHandle = title(ax,'Waiting for first stimulus...');
grid(ax,'on');

% M-wave window sample indices, using COMPUTEAMPLITUDES' convention
% (round(windowDefs./period)+11, sample 11 = t=0 given the -5 ms
% start) so the highlighted peak/trough match the computed amplitude
% for the common case. KNOWN LIMITATION: for a stimulus HREFLEX.
% COMPUTEAMPLITUDES flags as an outlier-duration correction (median
% peak/trough index used instead of that stim's own raw max/min -- see
% its header), the marker below still shows the raw in-window max/min,
% which will visually disagree with the displayed (corrected) M-wave
% number. Acceptable for the Phase 1 MVP; align the marker to the
% corrected indices in a later phase if this proves confusing in the
% lab.
mWaveWinDef  = [4.5e-3 20e-3];   % s; matches HREFLEX.COMPUTEAMPLITUDES
mWaveWinInds = round(mWaveWinDef ./ trial.period) + 11;

%% Replay the Trial Through the Online Pipeline
state = [];
numSamps = numel(trigAll);
for startInd = 1:options.chunkSize:numSamps
    endInd = min(startInd + options.chunkSize - 1,numSamps);
    chunk.times = trial.times(startInd:endInd);
    chunk.trig  = trigAll(startInd:endInd);
    chunk.tap   = tapAll(startInd:endInd);
    chunk.h     = hAll(startInd:endInd);

    [state,newAmps] = stepHreflexMonitor( ...
        state,chunk,trial.muscle,legSlot);

    if isempty(newAmps)
        continue;
    end

    latestSnippet = state.snippets(end,:);
    winMwave = latestSnippet(mWaveWinInds(1):mWaveWinInds(2));
    [valMax,indMax] = max(winMwave);
    [valMin,indMin] = min(winMwave);
    indMax = indMax + mWaveWinInds(1) - 1;
    indMin = indMin + mWaveWinInds(1) - 1;

    set(hSnippetLine,'YData',latestSnippet);
    set(hMwaveMarker,'XData',timesSnippetMs([indMin indMax]), ...
        'YData',[valMin valMax]);
    set(titleHandle,'String',sprintf( ...
        'Stim #%d - M-wave: %.3f mV',size(state.amps,1),newAmps(end,1)));
    drawnow limitrate;
end

end
