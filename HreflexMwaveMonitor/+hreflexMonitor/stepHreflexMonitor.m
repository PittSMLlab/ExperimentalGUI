function [state,newAmps] = stepHreflexMonitor(state,chunk,muscle,legSlot)
%STEPHREFLEXMONITOR Advance the online H-reflex M-wave pipeline by one
%data chunk for a single leg.
%
%   Feeds a new chunk of trigger/TAP/H-muscle samples through
%   DETECTSTIMARTIFACTONLINE, and for each newly finalized stimulus,
%   once its full snippet window (+55 ms past the artifact peak) has
%   arrived, extracts the H-reflex snippet (HREFLEX.EXTRACTSNIPPETS) and
%   recomputes M-/H-wave/noise amplitudes over the FULL accumulated set
%   of this trial's snippets so far (HREFLEX.COMPUTEAMPLITUDES). The
%   full-set recompute is required for parity with the offline
%   pipeline: COMPUTEAMPLITUDES' outlier-duration correction (median
%   peak/trough index) is a population statistic, so evaluating it on a
%   single new snippet at a time would silently disagree with the batch
%   result. A finalized detection whose snippet tail has not yet
%   arrived is held in a small pending list and retried on a later
%   call -- a bounded, safe delay, never a blocking wait.
%
%   COST NOTE: the recompute is O(numStimSoFar) per new stimulus (not
%   O(1)), an inherent consequence of exact parity -- a new stimulus
%   can shift which prior stimuli COMPUTEAMPLITUDES' outlier-duration
%   correction flags. This is only incurred once per stimulus (never
%   per loop iteration) and is cheap at the stimulus counts a
%   SpinalAdapt session produces (at most a few hundred); it has not
%   yet been measured against the "bounded per-update work" isolation
%   requirement at the lab, and should be before relying on this
%   alongside the live control loop (see the CPU/draw-load check in the
%   study README's validation section).
%
%   This is pure data processing -- no plotting, no figure/GUI handles
%   -- so it can be called identically by RUNHREFLEXMWAVEMONITOR (which
%   adds a persistent figure) and by the replay parity test (which does
%   not).
%
% Inputs:
%   state   - running pipeline state; pass [] on the first call to
%             initialize. Struct fields: detect (DETECTSTIMARTIFACTONLINE
%             state), hBuf (growing H-muscle EMG buffer), snippets
%             (numStim x 121 accumulated H-reflex EMG snippets),
%             onsetTimes (numStim x 1), amps (numStim x 3: M-wave,
%             H-wave, noise, mV), pending (numPending x 2: [onsetTime
%             artifactInd], awaiting a full snippet window), muscle,
%             legSlot
%   chunk   - 1x1 struct with fields times, trig, tap, h (all
%             numSamples x 1 arrays of this leg's new data)
%   muscle  - char; H-reflex muscle label, echoed into state for the
%             caller's figure title only (no effect on computation)
%   legSlot - 1 = right leg, 2 = left leg; selects which HREFLEX.* cell
%             slot this leg occupies (matches the +Hreflex namespace's
%             fixed right/left cell convention throughout)
%
% Outputs:
%   state   - updated running pipeline state to pass into the next
%             call. Additive field mWaveInds (numStim x 2: [indMin
%             indMax], sample indices into a 121-sample snippet) marks
%             the M-wave peak/trough HREFLEX.COMPUTEAMPLITUDES actually
%             used for each stimulus -- the stimulus's own raw in-
%             window max/min, or, for a stimulus flagged by
%             COMPUTEAMPLITUDES' outlier-duration correction, the
%             across-trial median index instead. Re-derived here (see
%             the COMPUTEAMPLITUDES NOTE below) so a caller's marker
%             matches the displayed (possibly corrected) amplitude.
%   newAmps - numNewStim x 3 array of amplitudes (M-wave, H-wave,
%             noise, mV) for stimuli newly finalized THIS call (0x3 if
%             none)
%
% Toolbox Dependencies:
%   None
%
% See also DETECTSTIMARTIFACTONLINE, HREFLEX.EXTRACTSNIPPETS,
%   HREFLEX.COMPUTEAMPLITUDES, RUNHREFLEXMWAVEMONITOR.

arguments
    state
    chunk   (1,1) struct
    muscle  (1,:) char
    legSlot (1,1) double {mustBeMember(legSlot,[1 2])}
end

snipEndS = 0.055;   % s; matches HREFLEX.EXTRACTSNIPPETS' snipEnd

if isempty(state)
    state = struct( ...
        'detect',[], ...
        'hBuf',zeros(0,1), ...
        'snippets',zeros(0,121), ... % -5:0.5:55 ms @ 2 kHz = 121 samples
        'onsetTimes',zeros(0,1), ...
        'amps',zeros(0,3), ...
        'mWaveInds',zeros(0,2), ...  % [indMin indMax] into a snippet
        'pending',zeros(0,2), ...    % [onsetTime artifactInd]
        'muscle',muscle, ...
        'legSlot',legSlot);
end

state.hBuf = [state.hBuf; chunk.h];

[state.detect,finalized] = hreflexMonitor.detectStimArtifactOnline( ...
    state.detect,chunk.times,chunk.trig,chunk.tap);
state.pending = [state.pending; finalized];

newAmps = zeros(0,3);
period = state.detect.period;
if isnan(period) || isempty(state.pending)
    return;
end

%% Resolve Any Pending Detections Whose Snippet Tail Has Now Arrived
snipEndSamps = round(snipEndS / period);
isReady = state.pending(:,2) + snipEndSamps <= numel(state.hBuf);
ready = state.pending(isReady,:);
state.pending(isReady,:) = [];

numNew = size(ready,1);
if numNew == 0
    return;
end

% both HREFLEX.EXTRACTSNIPPETS and HREFLEX.COMPUTEAMPLITUDES require a
% fixed 2-element (right, left) cell regardless of how many legs are
% actually being monitored; the unmonitored slot is left empty and is
% skipped internally by those functions.
emptyCell = {[]; []};
for ss = 1:numNew
    indsPeaks = emptyCell;
    indsPeaks{legSlot} = ready(ss,2);
    rawEMG = emptyCell;
    rawEMG{legSlot} = state.hBuf;
    snip = Hreflex.extractSnippets(indsPeaks,rawEMG);
    state.snippets(end+1,:) = snip{legSlot,1};
    state.onsetTimes(end+1,1) = ready(ss,1);
end

ampsCell = emptyCell;
ampsCell{legSlot} = state.snippets;
% suppress COMPUTEAMPLITUDES' expected "no snippets for leg %d" warning
% for the unmonitored leg slot, which is always empty in this single-
% leg (Phase 1) pipeline
[lastMsg,lastId] = lastwarn();
warnState = warning('off','all');
[amps,~,usedMedMinMaxInds] = Hreflex.computeAmplitudes(ampsCell);
warning(warnState);
lastwarn(lastMsg,lastId);

% V -> mV, matches GENERATEHREFLEXRECRUITMENTCURVES' convention
state.amps = 1000 * [amps{legSlot,1} amps{legSlot,2} amps{legSlot,3}];
newAmps = state.amps(end-numNew+1:end,:);

%% Re-Derive the M-Wave Peak/Trough Indices COMPUTEAMPLITUDES Used
% COMPUTEAMPLITUDES' outlier-duration correction (and the raw min/max
% indices it corrects from) live in a private local function, so are
% not directly retrievable -- only the per-stimulus outlier FLAG
% (usedMedMinMaxInds) is returned. Mirror that private function's
% min/max-then-population-median logic here (same math, duplicated
% because it cannot be called externally) so a caller's marker matches
% the displayed (possibly corrected) M-wave amplitude instead of
% always showing each stimulus's own raw in-window max/min.
mWaveWinDef  = [4.5e-3 20e-3];   % s; matches HREFLEX.COMPUTEAMPLITUDES
mWaveWinInds = round(mWaveWinDef ./ period) + 11;
winMwave = state.snippets(:,mWaveWinInds(1):mWaveWinInds(2));
[~,indsMinRaw] = min(winMwave,[],2);
[~,indsMaxRaw] = max(winMwave,[],2);
indMinMed = round(median(indsMinRaw));
indMaxMed = round(median(indsMaxRaw));

isOutlierDur = usedMedMinMaxInds{legSlot,1};   % M-wave column
indsMinFinal = indsMinRaw;
indsMaxFinal = indsMaxRaw;
indsMinFinal(isOutlierDur) = indMinMed;
indsMaxFinal(isOutlierDur) = indMaxMed;

state.mWaveInds = [indsMinFinal indsMaxFinal] + mWaveWinInds(1) - 1;

end
