function tests = testHreflexMwaveMonitorReplay()
%TESTHREFLEXMWAVEMONITORREPLAY Integration parity between the online
%H-reflex M-wave pipeline and the offline +Hreflex batch pipeline.
%
%   Replays a trial through STEPHREFLEXMONITOR (chunked, simulating
%   live/streaming cadence) and compares the resulting M-/H-wave/noise
%   amplitudes against the offline pipeline
%   (HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER + HREFLEX.EXTRACTSNIPPETS
%   + HREFLEX.COMPUTEAMPLITUDES) run once over the whole trial. This is
%   the primary correctness guarantee for the monitor: COMPUTEAMPLITUDES'
%   outlier-duration correction is a population statistic (see
%   GENERATESYNTHETICHREFLEXTRIAL's deliberately wide 3rd stimulus), so
%   this test would fail if STEPHREFLEXMONITOR evaluated amplitudes
%   per-stimulus instead of over the full growing snippet set.
%
%   Runs hardware-free against a synthetic fixture by default. A
%   companion lab-only test additionally replays a real prior
%   SpinalAdapt calibration C3D when one is configured (see
%   TESTREPLAYAGAINSTREALCALIBRATIONC3D); it is skipped, not failed,
%   when unconfigured, so CI is unaffected. Run with:
%   runtests('testHreflexMwaveMonitorReplay').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies:
%   None (the lab-only test additionally requires BTK; see
%   HREFLEXSOURCEREPLAYC3D)
%
% See also STEPHREFLEXMONITOR, DETECTSTIMARTIFACTONLINE,
%   HREFLEXSOURCEREPLAYC3D, GENERATESYNTHETICHREFLEXTRIAL,
%   HREFLEX.EXTRACTSNIPPETS, HREFLEX.COMPUTEAMPLITUDES.

tests = functiontests(localfunctions);

end

function testAmplitudeParityWithOfflinePipelineRightLeg(testCase)
%TESTAMPLITUDEPARITYWITHOFFLINEPIPELINERIGHTLEG See file header;
%exercised on the right-leg cell slot.
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
[amps,numStim] = replayTrialLeg(trial,1,17);
verifyEqual(testCase,numStim,5);

ampsOffline = computeOfflineAmps(trial,1);
verifyEqual(testCase,amps,ampsOffline,'AbsTol',1e-9);

end

function testGrowingSetOutlierCorrectionMattersRightLeg(testCase)
%TESTGROWINGSETOUTLIERCORRECTIONMATTERSRIGHTLEG Demonstrates that
%STEPHREFLEXMONITOR's growing-set recompute is load-bearing, not just
%equivalent by luck to a simpler per-stimulus approach. Uses a hand-
%crafted H-muscle signal (see BUILDOUTLIERTRIAL) where one stimulus's
%duration is confirmed below to actually trigger HREFLEX.
%COMPUTEAMPLITUDES' population-level outlier-duration correction. The
%growing-set (STEPHREFLEXMONITOR) result must then match the true
%offline batch result, while a (wrong) per-stimulus, N=1 computation --
%where ISOUTLIER can never fire -- must NOT.
trial = buildOutlierTrial();

% confirm the crafted signal actually engages the outlier correction --
% otherwise this test would not exercise the regression it targets
[ampsOffline,usedMedMinMaxInds] = computeOfflineAmps(trial,1);
verifyTrue(testCase,usedMedMinMaxInds{1,1}(5));

% growing-set (correct) computation, via STEPHREFLEXMONITOR
[ampsGrowing,~] = replayTrialLeg(trial,1,17);
verifyEqual(testCase,ampsGrowing,ampsOffline,'AbsTol',1e-9);

% a (wrong) per-stimulus computation: HREFLEX.COMPUTEAMPLITUDES called
% on each snippet alone (N=1), where the outlier correction can never
% engage -- must disagree with the growing-set result for stim 5
indsOffline = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,{trial.tapR,[]},{trial.trigR,[]});
snippetsAll = Hreflex.extractSnippets({indsOffline{1};[]}, ...
    {trial.hR;[]});
snippetsAll = snippetsAll{1,1};
ampsPerStim5Cell = Hreflex.computeAmplitudes( ...
    {snippetsAll(5,:);[]});
ampsPerStim5 = 1000 * ampsPerStim5Cell{1,1};

verifyNotEqual(testCase,ampsGrowing(5,1),ampsPerStim5);

end

function testMwaveMarkerIndsMatchDisplayedAmplitude(testCase)
%TESTMWAVEMARKERINDSMATCHDISPLAYEDAMPLITUDE STEPHREFLEXMONITOR's
%mWaveInds must index the same peak/trough RUNHREFLEXMWAVEMONITOR's
%marker plots as the displayed (possibly outlier-corrected) M-wave
%amplitude in state.amps -- otherwise the marker would visually
%disagree with the number next to it. Checked for every stimulus,
%including stim 5's outlier-corrected one, in BUILDOUTLIERTRIAL.
trial = buildOutlierTrial();
[amps,numStim,mWaveInds,snippets] = replayTrialLeg(trial,1,17);
verifyEqual(testCase,numStim,5);

for st = 1:numStim
    markerAmpMv = 1000 * abs(snippets(st,mWaveInds(st,2)) - ...
        snippets(st,mWaveInds(st,1)));
    verifyEqual(testCase,markerAmpMv,amps(st,1),'AbsTol',1e-9);
end

end

function testAmplitudeParityWithOfflinePipelineLeftLeg(testCase)
%TESTAMPLITUDEPARITYWITHOFFLINEPIPELINELEFTLEG Same parity guarantee
%as TESTAMPLITUDEPARITYWITHOFFLINEPIPELINERIGHTLEG, on the left-leg
%cell slot, confirming STEPHREFLEXMONITOR's leg-agnostic wiring.
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
[amps,numStim] = replayTrialLeg(trial,2,17);
verifyEqual(testCase,numStim,5);

ampsOffline = computeOfflineAmps(trial,2);
verifyEqual(testCase,amps,ampsOffline,'AbsTol',1e-9);

end

function testReplayAgainstRealCalibrationC3D(testCase)
%TESTREPLAYAGAINSTREALCALIBRATIONC3D Lab-only: replay a real prior
%SpinalAdapt H-reflex calibration C3D and confirm the online pipeline's
%stim count and M-wave amplitudes match the offline pipeline. Skipped
%(not failed) when no real trial is configured, so CI is unaffected;
%set the HREFLEX_REPLAY_TEST_C3D environment variable to a prior
%calibration trial's C3D path to run this in the lab.
c3dPath = getenv('HREFLEX_REPLAY_TEST_C3D');
testCase.assumeTrue(~isempty(c3dPath) && isfile(c3dPath), ...
    ['Set the HREFLEX_REPLAY_TEST_C3D environment variable to a ' ...
    'real calibration trial C3D path to run this lab-only test; ' ...
    'skipping (not failing) since none is configured.']);

trial = hreflexMonitor.hreflexSourceReplayC3D(c3dPath,'muscle','SOL');
% chunk size matches the ~20 subsamples/frame the probe checks for
[amps,~] = replayTrialLeg(trial,1,20);
ampsOffline = computeOfflineAmps(trial,1);

verifyEqual(testCase,size(amps,1),size(ampsOffline,1));
verifyEqual(testCase,amps,ampsOffline,'AbsTol',1e-6);

end

%% Local Functions

function trial = buildOutlierTrial()
%BUILDOUTLIERTRIAL Synthetic 5-stim trial with a hand-crafted H-muscle
%signal (unambiguous rectangular peak/trough pairs, not a continuous
%bump shape, so each stimulus's M-wave peak-to-trough duration in
%samples is known exactly and not left to window-truncation or noise
%interaction) where the last stimulus's duration is deliberately an
%outlier, engaging HREFLEX.COMPUTEAMPLITUDES' population-level
%outlier-duration correction.
%
% Inputs:
%   None
%
% Outputs:
%   trial - struct from GENERATESYNTHETICHREFLEXTRIAL with hR replaced
%
% Toolbox Dependencies:
%   None

trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);

period = trial.period;
troughOffsetS = 0.010;   % s after onset; lands inside the M-wave
% window once aligned to the (onset + 3 ms TAP artifact delay) snippet
% t=0, for every duration below
durationsSamples = [6 6 6 6 24];   % last stim deliberately an outlier
peakAmp = 0.01;   % V; far above the 1e-4 V background noise floor
hR = 1e-4 * randn(size(trial.times));
for st = 1:5
    troughTime = trial.onsetTimesR(st) + troughOffsetS;
    peakTime   = troughTime + durationsSamples(st) * period;
    troughInd  = round(troughTime / period) + 1;
    peakInd    = round(peakTime / period) + 1;
    hR(troughInd) = hR(troughInd) - peakAmp;
    hR(peakInd)   = hR(peakInd) + peakAmp;
end
trial.hR = hR;

end

function [amps,numStim,mWaveInds,snippets] = replayTrialLeg( ...
    trial,legSlot,chunkSize)
%REPLAYTRIALLEG Replay one leg of TRIAL through STEPHREFLEXMONITOR in
%fixed-size chunks (simulating streaming cadence) and return the final
%accumulated amplitudes.
%
% Inputs:
%   trial     - struct from HREFLEXSOURCEREPLAYC3D or
%               GENERATESYNTHETICHREFLEXTRIAL
%   legSlot   - 1 = right leg, 2 = left leg
%   chunkSize - samples per simulated streaming chunk
%
% Outputs:
%   amps      - numStim x 3 array (M-wave, H-wave, noise, mV)
%   numStim   - number of stimuli finalized
%   mWaveInds - numStim x 2 array; see STEPHREFLEXMONITOR's state.
%               mWaveInds
%   snippets  - numStim x 121 array; see STEPHREFLEXMONITOR's state.
%               snippets
%
% Toolbox Dependencies:
%   None

if legSlot == 1
    trigAll = trial.trigR;  tapAll = trial.tapR;  hAll = trial.hR;
else
    trigAll = trial.trigL;  tapAll = trial.tapL;  hAll = trial.hL;
end

state = [];
numSamps = numel(trigAll);
for startInd = 1:chunkSize:numSamps
    endInd = min(startInd + chunkSize - 1,numSamps);
    chunk.times = trial.times(startInd:endInd);
    chunk.trig  = trigAll(startInd:endInd);
    chunk.tap   = tapAll(startInd:endInd);
    chunk.h     = hAll(startInd:endInd);
    state = hreflexMonitor.stepHreflexMonitor( ...
        state,chunk,trial.muscle,legSlot);
end

amps = state.amps;
numStim = size(amps,1);
mWaveInds = state.mWaveInds;
snippets = state.snippets;

end

function [ampsOffline,usedMedMinMaxInds] = computeOfflineAmps(trial,legSlot)
%COMPUTEOFFLINEAMPS Run the whole-trial offline +Hreflex pipeline for
%one leg: HREFLEX.EXTRACTSTIMARTIFACTINDSFROMTRIGGER +
%HREFLEX.EXTRACTSNIPPETS + HREFLEX.COMPUTEAMPLITUDES.
%
%   NOTE: unlike GENERATEHREFLEXRECRUITMENTCURVES, this does not route
%   EMG through labTimeSeries (which zero-value-substitutes NaN); this
%   monitor's online pipeline does not do that substitution either, so
%   the two sides stay consistent with each other for this parity
%   check (a possible source of a small discrepancy if ever diffed
%   against that script's own saved output on real data).
%
% Inputs:
%   trial   - struct from HREFLEXSOURCEREPLAYC3D or
%             GENERATESYNTHETICHREFLEXTRIAL
%   legSlot - 1 = right leg, 2 = left leg
%
% Outputs:
%   ampsOffline       - numStim x 3 array (M-wave, H-wave, noise, mV)
%   usedMedMinMaxInds - HREFLEX.COMPUTEAMPLITUDES' 2 x 2 cell of
%                       outlier-duration correction flags (see its
%                       header); returned as-is for tests that need to
%                       confirm the correction actually engaged
%
% Toolbox Dependencies:
%   None

emptyCell = {[]; []};
trigCell = emptyCell;  tapCell = emptyCell;  hCell = emptyCell;
if legSlot == 1
    trigCell{1} = trial.trigR;  tapCell{1} = trial.tapR;
    hCell{1}    = trial.hR;
else
    trigCell{2} = trial.trigL;  tapCell{2} = trial.tapL;
    hCell{2}    = trial.hL;
end

indsOffline = Hreflex.extractStimArtifactIndsFromTrigger( ...
    trial.times,tapCell,trigCell);
indsPeaks = emptyCell;
indsPeaks{legSlot} = indsOffline{legSlot};

snippets = Hreflex.extractSnippets(indsPeaks,hCell);
ampsCell = emptyCell;
ampsCell{legSlot} = snippets{legSlot,1};
[amps,~,usedMedMinMaxInds] = Hreflex.computeAmplitudes(ampsCell);
ampsOffline = 1000 * [amps{legSlot,1} amps{legSlot,2} amps{legSlot,3}];

end
