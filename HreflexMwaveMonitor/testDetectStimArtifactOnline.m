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
%   re-implementation. Also pins the polarity-agnostic localization
%   rule both share, using a negative-dominant artifact fixture -- the
%   real-world case (SpinalAdapt, 2026-08-21) that the earlier
%   signed-positive peak search mislocalized. Run with:
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
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
finalized = runOnlineDetectorChunked( ...
    trial.times,trial.trigR,trial.tapR,17);
verifyEqual(testCase,size(finalized,1),5);

end

function testChunkSizeInvarianceOfFinalizedIndices(testCase)
%TESTCHUNKSIZEINVARIANCEOFFINALIZEDINDICES The set of finalized
%artifact indices must not depend on how the same signal is chunked
%(a correctness property streaming code must have to be a faithful
%re-implementation of a whole-trial algorithm).
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
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
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',1);
period = trial.period;
onsetSamp = find(trial.trigR > 2.5,1,'first');

% feed only up to 50 ms after onset: not yet a full 100 ms window
cutoffInd = onsetSamp + round(0.05 / period);
state = [];
[state,finalizedEarly] = hreflexMonitor.detectStimArtifactOnline( ...
    state,trial.times(1:cutoffInd),trial.trigR(1:cutoffInd), ...
    trial.tapR(1:cutoffInd));
verifyEqual(testCase,size(finalizedEarly,1),0);
verifyEqual(testCase,numel(state.pendingOnsetTimes),1);

% now feed the rest: the full window has arrived, so it finalizes
[~,finalizedLater] = hreflexMonitor.detectStimArtifactOnline( ...
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
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);

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
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);

finalizedOnline = runOnlineDetectorChunked( ...
    trial.times,trial.trigL,trial.tapL,13);
indsOnline = sort(finalizedOnline(:,2));

indsOffline = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{[],trial.tapL},{[],trial.trigL});
indsOffline = sort(indsOffline{2});

verifyEqual(testCase,indsOnline,indsOffline);

end

function testLocalizesNegativeDominantArtifact(testCase)
%TESTLOCALIZESNEGATIVEDOMINANTARTIFACT Both the online detector and the
%offline helper must land on the artifact's initial NEGATIVE deflection
%when it dominates a smaller positive rebound, and must do so even
%though neither lobe clears the old 1 mV peak-height threshold. This is
%the regression test for the SpinalAdapt 2026-08-21 calibration trial,
%where the signed-positive search found no peak at all and silently
%fell back to the raw maximum over the whole 200 ms search window.
trial = buildNegativeDominantTrial();

finalizedOnline = runOnlineDetectorChunked( ...
    trial.times,trial.trig,trial.tap,29);
verifyEqual(testCase,sort(finalizedOnline(:,2)),trial.indsArtifact);

% the fixture's artifact is deliberately below the quality control
% floor, so the offline helper warns; that warning is asserted on by
% TESTFLAGSWEAKARTIFACTBELOWQUALITYFLOOR and only muted here
warnState = warning('off','Hreflex:weakStimArtifact');
indsOffline = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{trial.tap,[]},{trial.trig,[]});
warning(warnState);
verifyEqual(testCase,sort(indsOffline{1}),trial.indsArtifact);

end

function testFlagsWeakArtifactBelowQualityFloor(testCase)
%TESTFLAGSWEAKARTIFACTBELOWQUALITYFLOOR The offline helper's
%minArtifactPeak is a quality control floor, not a detection gate: a
%stimulus below it is still localized, but is reported in the
%isWeakArtifact output so a disabled stimulator or detached electrode
%is visible rather than silently analyzed.
trial = buildNegativeDominantTrial();
numStim = numel(trial.indsArtifact);

warnState = warning('off','Hreflex:weakStimArtifact');
[indsHighFloor,isWeakHighFloor] = ...
    Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{trial.tap,[]},{trial.trig,[]}, ...
    'minArtifactPeak',1e-3);   % above the fixture's artifact
warning(warnState);
verifyEqual(testCase,numel(indsHighFloor{1}),numStim);
verifyTrue(testCase,all(isWeakHighFloor{1}));

[~,isWeakLowFloor] = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{trial.tap,[]},{trial.trig,[]}, ...
    'minArtifactPeak',1e-4);   % below the fixture's artifact
verifyFalse(testCase,any(isWeakLowFloor{1}));

end

%% Local Functions

function trial = buildNegativeDominantTrial()
%BUILDNEGATIVEDOMINANTTRIAL Synthesize one leg whose stim artifact is
%negative-dominant and below the 1 mV quality control floor.
%
%   Each stimulus produces a downward deflection followed 1.5 ms later
% by a smaller positive rebound -- the shape measured on real
% SpinalAdapt proximal TA data -- placed 50 ms after the trigger rising
% edge to mirror the Delsys wireless transmission delay.
%
% Inputs:
%   None
%
% Outputs:
%   trial - struct with fields times, trig, tap (numSamples x 1) and
%           indsArtifact (numStim x 1 ground-truth artifact indices,
%           ascending)
%
% Toolbox Dependencies:
%   None

period  = 0.0005;   % 2 kHz, matches labTools' +Hreflex assumption
times   = (0:period:3.0)';
numStim = 4;
onsetTimes = 0.5 + (0:numStim - 1)' * 0.6;  % s; well separated

pulseDur      = 0.02;    % s; trigger pulse duration
artifactDelay = 0.050;   % s; ~Delsys wireless transmission delay
reboundDelay  = 0.0015;  % s; measured artifact trough-to-peak spacing
ampNeg        = 6e-4;    % V; initial downward deflection
ampPos        = 3e-4;    % V; smaller positive rebound
% NOTE: both lobes sit below the 1e-3 V default minArtifactPeak, so a
% peak-height-gated search finds nothing to lock onto

rng(7);   % reproducible synthetic noise across test runs
trig = zeros(size(times));
tap  = 2e-5 * randn(size(times));
indsArtifact = nan(numStim,1);

for st = 1:numStim
    onset = onsetTimes(st);
    trig(times >= onset & times < onset + pulseDur) = 5;
    [~,indNeg] = min(abs(times - (onset + artifactDelay)));
    indPos = indNeg + round(reboundDelay / period);
    tap(indNeg) = tap(indNeg) - ampNeg;
    tap(indPos) = tap(indPos) + ampPos;
    indsArtifact(st) = indNeg;
end

trial.times        = times;
trial.trig         = trig;
trial.tap          = tap;
trial.indsArtifact = indsArtifact;

end

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
    [state,newFinalized] = hreflexMonitor.detectStimArtifactOnline( ...
        state,times(startInd:endInd),trig(startInd:endInd), ...
        tap(startInd:endInd));
    finalized = [finalized; newFinalized]; %#ok<AGROW>
end

end
