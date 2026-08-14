function [state,finalized] = detectStimArtifactOnline(state, ...
    chunkTimes,chunkTrig,chunkTAP,options)
%DETECTSTIMARTIFACTONLINE Causal, streaming H-reflex stim artifact
%detector for one leg.
%
%   Causal re-implementation of the two private subfunctions inside
%   labTools' HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER
%   (getStimOnsetTimes, findStimArtifactInds): detects the rising edge
%   of the stimulation trigger pulse, then locates the artifact peak in
%   the proximal TA EMG signal, exactly like the offline (whole-trial)
%   helper, but incrementally, chunk by chunk, as new samples arrive. A
%   detected onset is only "finalized" into an artifact index once
%   enough future samples exist to search the same +-winDurStim window
%   the offline helper uses -- a bounded delay (default 100 ms), never
%   a blocking wait. This is a re-implementation, not a call into the
%   offline helper (which is whole-trial / non-causal); a companion
%   parity test (TESTDETECTSTIMARTIFACTONLINE) checks the two agree
%   sample-for-sample when run over the same trial data.
%
% Inputs:
%   state      - running detector state; pass [] on the first call to
%                initialize. Struct fields: times, trig, tap (growing
%                buffers of everything seen so far), wasAboveThresh
%                (logical; trigger state at the end of the previous
%                chunk), pendingOnsetTimes (onsets awaiting enough
%                future samples to finalize), period (s; cached from
%                the first two samples)
%   chunkTimes - numSamples x 1 array of new sample times (s), relative
%                to trial start, contiguous with any previous chunk
%   chunkTrig  - numSamples x 1 array of new stimulation trigger
%                samples (V)
%   chunkTAP   - numSamples x 1 array of new proximal TA EMG samples
%                (V)
%
% Optional Name-Value Inputs:
%   threshStim      - stim trigger pulse detection threshold, V
%                     (default: 2.5, matches HREFLEX.
%                     EXTRACTSTIMARTIFACTINDSFROMTRIGGER)
%   winDurStim      - search window duration around trigger pulse, s
%                     (default: 0.1, matches the offline helper)
%   minArtifactPeak - minimum stim artifact peak height, V (default:
%                     0.001, matches the offline helper)
%
% Outputs:
%   state     - updated running state to pass into the next call
%   finalized - numNewlyFinalized x 2 array, columns [onsetTime
%               artifactInd]; artifactInd indexes into
%               state.times/state.tap (the full buffer seen so far).
%               0x2 if none finalized this call.
%
% Toolbox Dependencies:
%   None
%
% See also HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER, STEPHREFLEXMONITOR,
%   TESTDETECTSTIMARTIFACTONLINE.

arguments
    state
    chunkTimes (:,1) double
    chunkTrig  (:,1) double
    chunkTAP   (:,1) double
    options.threshStim      (1,1) double {mustBePositive} = 2.5
    options.winDurStim      (1,1) double {mustBePositive} = 0.1
    options.minArtifactPeak (1,1) double {mustBePositive} = 0.001
end

if isempty(state)  % first call: initialize the running detector state
    state = struct( ...
        'times',zeros(0,1), ...
        'trig',zeros(0,1), ...
        'tap',zeros(0,1), ...
        'wasAboveThresh',false, ...
        'pendingOnsetTimes',zeros(0,1), ...
        'period',NaN);
end

finalized = zeros(0,2);   % [onsetTime artifactInd]; none yet this call
if isempty(chunkTimes)
    return;
end

%% Detect New Rising Edges (Causal Equivalent of GETSTIMONSETTIMES)
% a rising edge is a sample above threshStim immediately preceded by a
% sample at or below threshStim; wasAboveThresh carries that boundary
% condition across chunks (equivalent to the offline helper's
% "diff([0; indsStimAll]) > 1", where the prepended 0 plays the same
% role as wasAboveThresh = false at trial start)
aboveNew  = chunkTrig > options.threshStim;
prevAbove = [state.wasAboveThresh; aboveNew(1:end-1)];
isEdge    = aboveNew & ~prevAbove;
state.wasAboveThresh = aboveNew(end);

%% Append the New Chunk to the Running Buffers
state.times = [state.times; chunkTimes];
state.trig  = [state.trig;  chunkTrig];
state.tap   = [state.tap;   chunkTAP];
if isnan(state.period) && numel(state.times) >= 2
    state.period = state.times(2) - state.times(1);
end
state.pendingOnsetTimes = [state.pendingOnsetTimes; chunkTimes(isEdge)];

%% Finalize Any Onsets With a Full Search Window Now Available
if isempty(state.pendingOnsetTimes) || isnan(state.period)
    return;
end

winSamples = round(options.winDurStim / state.period);
isResolved = false(numel(state.pendingOnsetTimes),1);
for pp = 1:numel(state.pendingOnsetTimes)
    onsetTime = state.pendingOnsetTimes(pp);
    [~,indStim] = min(abs(state.times - onsetTime));
    if numel(state.times) < indStim + winSamples
        continue;   % not enough future samples yet; retry next call
    end
    isResolved(pp) = true;

    winSearch = max(1,indStim - winSamples): ...
        min(numel(state.tap),indStim + winSamples);
    % suppress findpeaks' expected "Invalid MinPeakHeight" warning for a
    % window with no qualifying peak (falls back to raw max below,
    % exactly like HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER's private
    % findStimArtifactInds, which emits the identical warning on the
    % same real data -- benign, but noisy on a live monitor console)
    warnState = warning('off','signal:findpeaks:largeMinPeakHeight');
    [~,locs] = findpeaks(state.tap(winSearch), ...
        'MinPeakHeight',options.minArtifactPeak);
    warning(warnState);
    if isempty(locs)             % if no peaks detected, ...
        [~,indMaxTAP] = max(state.tap(winSearch)); % use max as peak
    else                         % otherwise, ...
        indMaxTAP = locs(1);     % use first (earliest) peak
    end
    finalized(end+1,:) = [onsetTime winSearch(indMaxTAP)]; %#ok<AGROW>
end
state.pendingOnsetTimes(isResolved) = [];

end
