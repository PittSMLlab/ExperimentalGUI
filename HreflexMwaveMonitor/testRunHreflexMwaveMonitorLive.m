function tests = testRunHreflexMwaveMonitorLive()
%TESTRUNHREFLEXMWAVEMONITORLIVE End-to-end tests of the live monitor loop.
%
%   Runs RUNHREFLEXMWAVEMONITORLIVE against a fake source that delivers a
% synthetic trial frame by frame, so everything except the Vicon SDK calls
% in HREFLEXSOURCEDATASTREAM is exercised, including the exit path. Each
% fake run ends with an error from the source, which fires the same
% onCleanup as Ctrl+C. Opens a figure briefly. Run with:
% runtests('testRunHreflexMwaveMonitorLive').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies:
%   None (external: labTools +Hreflex namespace)
%
% See also RUNHREFLEXMWAVEMONITORLIVE, STEPHREFLEXMONITOR,
%   GENERATESYNTHETICHREFLEXTRIAL.

tests = functiontests(localfunctions);

end

function testAbortSavesLogAndClosesSource(testCase)
%TESTABORTSAVESLOGANDCLOSESSOURCE An interrupted run still disconnects
%and saves its log. This failed when the cleanup used nested-function
%variables, which MATLAB had already destroyed when onCleanup fired.
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
[source,control] = buildFakeSource(trial,[]);
outDir = setUpRun(testCase);

runUntilSourceEnds(testCase,source,outDir);

verifyTrue(testCase,control('isClosed'));
monitorLog = loadOnlyLog(testCase,outDir);
verifyEqual(testCase,monitorLog.leg,'R');
verifyEqual(testCase,monitorLog.sourceState.numLostFrames,0);

end

function testLiveAmplitudesMatchChunkedReplay(testCase)
%TESTLIVEAMPLITUDESMATCHCHUNKEDREPLAY With no lost frames, and the trigger
%read once per frame as it is live, the loop logs the same amplitudes as
%running the full trigger through STEPHREFLEXMONITOR.
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
[source,~] = buildFakeSource(trial,[]);
outDir = setUpRun(testCase);

runUntilSourceEnds(testCase,source,outDir);

monitorLog = loadOnlyLog(testCase,outDir);
state = [];
for startInd = 1:20:numel(trial.trigR) - 19
    endInd = startInd + 19;
    chunk.times = trial.times(startInd:endInd);
    chunk.trig  = trial.trigR(startInd:endInd);
    chunk.tap   = trial.tapR(startInd:endInd);
    chunk.h     = trial.hR(startInd:endInd);
    state = hreflexMonitor.stepHreflexMonitor(state,chunk,'SOL',1);
end
verifyEqual(testCase,size(monitorLog.amps,1),5);
verifyEqual(testCase,monitorLog.amps,state.amps,'AbsTol',1e-9);
verifyEqual(testCase,numel(monitorLog.stimDelayS),5);

end

function testLostFramesMarkOnlyTheAffectedStimulusInvalid(testCase)
%TESTLOSTFRAMESMARKONLYTHEAFFECTEDSTIMULUSINVALID A frame lost during one
%stimulus's snippet leaves that stimulus invalid, and the rest logged.
trial = hreflexMonitor.generateSyntheticHreflexTrial('numStim',5);
onset = trial.onsetTimesR(2);
frameToLose = floor((onset + 0.020) / 0.01) + 1;
[source,~] = buildFakeSource(trial,frameToLose);
outDir = setUpRun(testCase);

runUntilSourceEnds(testCase,source,outDir);

monitorLog = loadOnlyLog(testCase,outDir);
verifyEqual(testCase,monitorLog.sourceState.numLostFrames,1);
verifyEqual(testCase,size(monitorLog.amps,1),4);
verifyEqual(testCase,monitorLog.invalidOnsetTimes,onset,'AbsTol',0.02);

end

%% Local Functions

function outDir = setUpRun(testCase)
%SETUPRUN Make a temporary log folder and clean up after the test.
%
% Inputs:
%   testCase - function-based test case
%
% Outputs:
%   outDir - char; temporary folder for the run's log
%
% Toolbox Dependencies:
%   None

outDir = tempname;
mkdir(outDir);
testCase.addTeardown(@() rmdir(outDir,'s'));
testCase.addTeardown(@() delete(findall(0,'Type','figure', ...
    'Name','H-Reflex M-Wave Monitor (R, SOL)')));

end

function runUntilSourceEnds(testCase,source,outDir)
%RUNUNTILSOURCEENDS Run the monitor until the fake source errors out.
%
% Inputs:
%   testCase - function-based test case
%   source   - fake source struct from BUILDFAKESOURCE
%   outDir   - char; folder for the run's log
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None

verifyError(testCase,@() hreflexMonitor.runHreflexMwaveMonitorLive( ...
    'R',1,2,'baselineMwaveMv',1,'outputDir',outDir,'source',source), ...
    'testRunHreflexMwaveMonitorLive:endOfData');

end

function monitorLog = loadOnlyLog(testCase,outDir)
%LOADONLYLOG Load the single log file a run should have saved.
%
% Inputs:
%   testCase - function-based test case
%   outDir   - char; folder holding the log
%
% Outputs:
%   monitorLog - struct saved by RUNHREFLEXMWAVEMONITORLIVE
%
% Toolbox Dependencies:
%   None

logFiles = dir(fullfile(outDir,'HreflexMonitorLive_R_*.mat'));
assertEqual(testCase,numel(logFiles),1);
loaded = load(fullfile(outDir,logFiles(1).name),'monitorLog');
monitorLog = loaded.monitorLog;

end

function [source,control] = buildFakeSource(trial,framesToLose)
%BUILDFAKESOURCE Build a source that replays a trial's right leg by frame.
%
% Inputs:
%   trial        - struct from GENERATESYNTHETICHREFLEXTRIAL
%   framesToLose - frame numbers to skip delivering, or []
%
% Outputs:
%   source  - struct shaped like HREFLEXSOURCEDATASTREAM's output
%   control - containers.Map; 'nextFrame' and 'isClosed'
%
% Toolbox Dependencies:
%   None

control = containers.Map();
control('nextFrame') = 1;
control('isClosed')  = false;

source.period    = trial.period;
source.readFrame = @() readFakeFrame(trial,framesToLose,control);
source.close     = @() markClosed(control);

end

function [hasFrame,frame] = readFakeFrame(trial,framesToLose,control)
%READFAKEFRAME Return the next frame, reading the trigger once per frame
%as HREFLEXSOURCEDATASTREAM does, then error when the trial runs out.
%
% Inputs:
%   trial        - struct from GENERATESYNTHETICHREFLEXTRIAL
%   framesToLose - frame numbers to skip delivering, or []
%   control      - containers.Map from BUILDFAKESOURCE
%
% Outputs:
%   hasFrame - always true when it returns
%   frame    - struct with frameNum, tap, h, trig
%
% Toolbox Dependencies:
%   None

numPerFrame = 20;
frameNum = control('nextFrame');
while ismember(frameNum,framesToLose)
    frameNum = frameNum + 1;
end
control('nextFrame') = frameNum + 1;

inds = (frameNum - 1) * numPerFrame + (1:numPerFrame)';
if inds(end) > numel(trial.trigR)
    error('testRunHreflexMwaveMonitorLive:endOfData', ...
        'The fake source has no more frames.');
end

hasFrame = true;
frame.frameNum = frameNum;
frame.tap  = trial.tapR(inds);
frame.h    = trial.hR(inds);
frame.trig = trial.trigR(inds(1));

end

function markClosed(control)
%MARKCLOSED Record that the monitor closed the fake source.
%
% Inputs:
%   control - containers.Map from BUILDFAKESOURCE
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None

control('isClosed') = true;

end
