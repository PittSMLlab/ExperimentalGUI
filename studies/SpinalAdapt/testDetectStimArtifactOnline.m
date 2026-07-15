function tests = testDetectStimArtifactOnline()
%TESTDETECTSTIMARTIFACTONLINE Unit and online-vs-offline parity tests
%for the causal stim artifact detector.
%
%   Validates DETECTSTIMARTIFACTONLINE's streaming behavior (chunk-size
%   independence, bounded finalization delay) and, critically, that its
%   causal re-implementation of HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER's
%   private subfunctions agrees sample-for-sample with that offline,
%   whole-trial helper when run over identical synthetic data
%   (GENERATESYNTHETICHREFLEXTRIAL) -- the online path is a faithful
%   re-implementation, not a call into the offline helper, so this
%   parity check is the load-bearing correctness test for that
%   re-implementation. Run with:
%   runtests('testDetectStimArtifactOnline').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies:
%   None
%
% See also DETECTSTIMARTIFACTONLINE,
%   HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER,
%   GENERATESYNTHETICHREFLEXTRIAL.

tests = functiontests(localfunctions);

end

function testFinalizesExpectedNumberOfStimuli(testCase)
%TESTFINALIZESEXPECTEDNUMBEROFSTIMULI Every synthesized stim is
%eventually finalized exactly once, none dropped or duplicated.
trial = generateSyntheticHreflexTrial('numStim',5);
finalized = runOnlineDetectorChunked( ...
    trial.times,trial.trigR,trial.tapR,17);
verifyEqual(testCase,size(finalized,1),5);

end

function testChunkSizeInvarianceOfFinalizedIndices(testCase)
%TESTCHUNKSIZEINVARIANCEOFFINALIZEDINDICES The set of finalized
%artifact indices must not depend on how the same signal is chunked
%(a correctness property streaming code must have to be a faithful
%re-implementation of a whole-trial algorithm).
trial = generateSyntheticHreflexTrial('numStim',5);
finalizedSmallChunks = runOnlineDetectorChunked( ...
    trial.times,trial.trigR,trial.tapR,1);
finalizedLargeChunks = runOnlineDetectorChunked( ...
    trial.times,trial.trigR,trial.tapR,123);
verifyEqual(testCase,sortrows(finalizedSmallChunks), ...
    sortrows(finalizedLargeChunks));

end

function testNoFinalizationBeforeFullSearchWindowArrives(testCase)
%TESTNOFINALIZATIONBEFOREFULLSEARCHWINDOWARRIVES A detected onset must
%stay pending (not finalized) until winDurStim (default 100 ms) of
%future samples have arrived -- the bounded, non-blocking delay
%DETECTSTIMARTIFACTONLINE documents.
trial = generateSyntheticHreflexTrial('numStim',1);
period = trial.period;
onsetSamp = find(trial.trigR > 2.5,1,'first');

% feed only up to 50 ms after onset: not yet a full 100 ms window
cutoffInd = onsetSamp + round(0.05 / period);
state = [];
[state,finalizedEarly] = detectStimArtifactOnline( ...
    state,trial.times(1:cutoffInd),trial.trigR(1:cutoffInd), ...
    trial.tapR(1:cutoffInd));
verifyEqual(testCase,size(finalizedEarly,1),0);
verifyEqual(testCase,numel(state.pendingOnsetTimes),1);

% now feed the rest: the full window has arrived, so it finalizes
[~,finalizedLater] = detectStimArtifactOnline( ...
    state,trial.times(cutoffInd + 1:end), ...
    trial.trigR(cutoffInd + 1:end),trial.tapR(cutoffInd + 1:end));
verifyEqual(testCase,size(finalizedLater,1),1);

end

function testParityWithOfflineHelperRightLeg(testCase)
%TESTPARITYWITHOFFLINEHELPERRIGHTLEG The online causal detector must
%find the identical artifact sample indices HREFLEX.
%EXTRACTSTIMARTIFACTINDSFROMTRIGGER finds when run over the whole
%trial at once -- this is the core parity guarantee for the
%re-implementation.
trial = generateSyntheticHreflexTrial('numStim',5);

finalizedOnline = runOnlineDetectorChunked( ...
    trial.times,trial.trigR,trial.tapR,13);
indsOnline = sort(finalizedOnline(:,2));

indsOffline = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{trial.tapR,[]},{trial.trigR,[]});
indsOffline = sort(indsOffline{1});

verifyEqual(testCase,indsOnline,indsOffline);

end

function testParityWithOfflineHelperLeftLeg(testCase)
%TESTPARITYWITHOFFLINEHELPERLEFTLEG Same parity guarantee as
%TESTPARITYWITHOFFLINEHELPERRIGHTLEG, exercised on the left-leg cell
%slot to confirm the detector's leg-agnostic behavior.
trial = generateSyntheticHreflexTrial('numStim',5);

finalizedOnline = runOnlineDetectorChunked( ...
    trial.times,trial.trigL,trial.tapL,13);
indsOnline = sort(finalizedOnline(:,2));

indsOffline = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{[],trial.tapL},{[],trial.trigL});
indsOffline = sort(indsOffline{2});

verifyEqual(testCase,indsOnline,indsOffline);

end

%% Local Functions

function finalized = runOnlineDetectorChunked(times,trig,tap,chunkSize)
%RUNONLINEDETECTORCHUNKED Replay a full signal through
%DETECTSTIMARTIFACTONLINE in fixed-size chunks and collect every
%finalized detection.
%
% Inputs:
%   times, trig, tap - numSamples x 1 arrays (see
%                       DETECTSTIMARTIFACTONLINE)
%   chunkSize        - samples per simulated streaming chunk
%
% Outputs:
%   finalized - numStim x 2 array, columns [onsetTime artifactInd],
%               accumulated across all chunks
%
% Toolbox Dependencies:
%   None

state = [];
finalized = zeros(0,2);
numSamps = numel(times);
for startInd = 1:chunkSize:numSamps
    endInd = min(startInd + chunkSize - 1,numSamps);
    [state,newFinalized] = detectStimArtifactOnline(state, ...
        times(startInd:endInd),trig(startInd:endInd), ...
        tap(startInd:endInd));
    finalized = [finalized; newFinalized]; %#ok<AGROW>
end

end
