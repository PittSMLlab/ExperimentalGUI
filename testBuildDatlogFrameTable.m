function tests = testBuildDatlogFrameTable()
%TESTBUILDDATLOGFRAMETABLE Unit tests for BUILDDATLOGFRAMETABLE.
%
%   Hardware-free validation of the consolidated per-frame datlog view:
%   builds small synthetic datlogs (5 frames) covering the happy path,
%   each optional source's join rule, and the legacy/absent-field
%   defaults that make the helper safe to run on already-collected
%   datlogs. Run with: runtests('testBuildDatlogFrameTable').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO.

tests = functiontests(localfunctions);

end

function testHappyPathRowCountAndTimeline(testCase)
%TESTHAPPYPATHROWCOUNTANDTIMELINE Row count/frame#/relTime pass through.
datlog = makeBaseDatlog();
frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,height(frameTable),5);
verifyEqual(testCase,frameTable.frameNum,(101:105)');
verifyTrue(testCase,issorted(frameTable.rowTimes));
verifyEqual(testCase,frameTable.relTime, ...
    datlog.forces.data(:,5),'AbsTol',1e-9);

end

function testHappyPathForcesColumns(testCase)
%TESTHAPPYPATHFORCESCOLUMNS Rfz/Lfz pass through from forces.data.
datlog = makeBaseDatlog();
frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.Rfz,datlog.forces.data(:,3));
verifyEqual(testCase,frameTable.Lfz,datlog.forces.data(:,4));

end

function testBeltSpeedReadNearestJoin(testCase)
%TESTBELTSPEEDREADNEARESTJOIN Bertec-reported speeds join per frame.
datlog = makeBaseDatlog();
uTime   = datlog.forces.data(:,2);
RBS     = [500;520;540;560;580];
LBS     = [510;530;550;570;590];
angle   = zeros(5,1);
datlog.TreadmillCommands.read = [RBS LBS angle uTime];

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.beltSpeedRRead,RBS);
verifyEqual(testCase,frameTable.beltSpeedLRead,LBS);
verifyEqual(testCase,frameTable.inclineRead,angle);

end

function testReadRowOffsetByOneFrameStillNearestJoins(testCase)
%TESTREADROWOFFSETBYONEFRAMESTILLNEARESTJOINS A read logged slightly
%off its matching force frame still lands on the closer frame (mirrors
%the controller's real pre-/post-increment frameind write-order skew).
datlog = makeBaseDatlog();
uTime  = datlog.forces.data(:,2);
dt     = uTime(2) - uTime(1);

% shift every read time forward by 0.2*dt: still closest to the frame
% it was logged alongside, not the next one
readTime = uTime + 0.2*dt;
RBS      = [500;520;540;560;580];
LBS      = [510;530;550;570;590];
datlog.TreadmillCommands.read = [RBS LBS zeros(5,1) readTime];

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.beltSpeedRRead,RBS);

end

function testBeltSpeedCommandedCausalHold(testCase)
%TESTBELTSPEEDCOMMANDEDCAUSALHOLD Commanded speed holds the last known
%value and never looks ahead to a future command.
datlog = makeBaseDatlog();
uTime  = datlog.forces.data(:,2);

datlog.TreadmillCommands.firstSent = [300 400 500 500 0 uTime(1)-1];
% the single commanded-speed change lands exactly at frame index 3
datlog.TreadmillCommands.sent = [800 900 0 uTime(3) NaN];

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.beltSpeedRCmd,[300;300;800;800;800]);
verifyEqual(testCase,frameTable.beltSpeedLCmd,[400;400;900;900;900]);

end

function testGaitEventFrameJoin(testCase)
%TESTGAITEVENTFRAMEJOIN Stepdata events land on their exact frame#.
datlog   = makeBaseDatlog();
frameNum = datlog.forces.data(:,1);
uTime    = datlog.forces.data(:,2);

% RHS at frame index 2, LHS at frame index 3, RTO at frame index 4
datlog.stepdata.RHSdata = [1 uTime(2) frameNum(2) 0];
datlog.stepdata.RTOdata = [2 uTime(4) frameNum(4) 0];
datlog.stepdata.LHSdata = [1 uTime(3) frameNum(3) 0];
datlog.stepdata.LTOdata = []; % field present but empty

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.isRHS,logical([0;1;0;0;0]));
verifyEqual(testCase,frameTable.isRTO,logical([0;0;0;1;0]));
verifyEqual(testCase,frameTable.isLHS,logical([0;0;1;0;0]));
verifyEqual(testCase,frameTable.isLTO,false(5,1));

end

function testGaitEventIgnoresUnfilledPadRow(testCase)
%TESTGAITEVENTIGNORESUNFILLEDPADROW A preallocated-but-never-filled
%all-zero stepdata row (frame# = 0) is dropped, not matched.
datlog   = makeBaseDatlog();
frameNum = datlog.forces.data(:,1);
uTime    = datlog.forces.data(:,2);

datlog.stepdata.RHSdata = [1 uTime(2) frameNum(2) 0; 0 0 0 0];

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.isRHS,logical([0;1;0;0;0]));
verifyEqual(testCase,sum(frameTable.isRHS),1);

end

function testStimGateNearestJoin(testCase)
%TESTSTIMGATENEARESTJOIN A stim gate send lands on its nearest frame
%with the matching delay target; the opposite side stays all-false.
datlog = makeBaseDatlog();
uTime  = datlog.forces.data(:,2);

datlog.stim.L = [1 198.3 uTime(2)+1e-9];
datlog.stim.R = [];

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,frameTable.stimGateL,logical([0;1;0;0;0]));
verifyEqual(testCase,frameTable.stimDelayTargetL(2),198.3,'AbsTol',1e-9);
verifyTrue(testCase,isnan(frameTable.stimDelayTargetL(1)));
verifyEqual(testCase,frameTable.stimGateR,false(5,1));

end

function testLegacyDatlogMissingOptionalFields(testCase)
%TESTLEGACYDATLOGMISSINGOPTIONALFIELDS A datlog with only forces.data
%(no TreadmillCommands/stepdata/stim, as in an older log) still builds
%a valid table with every optional column defaulted.
datlog = makeBaseDatlog();

frameTable = utils.buildDatlogFrameTable(datlog);

verifyEqual(testCase,height(frameTable),5);
verifyTrue(testCase,all(isnan(frameTable.beltSpeedRRead)));
verifyTrue(testCase,all(isnan(frameTable.beltSpeedRCmd)));
verifyEqual(testCase,frameTable.isRHS,false(5,1));
verifyEqual(testCase,frameTable.stimGateL,false(5,1));
verifyTrue(testCase,all(isnan(frameTable.stimDelayTargetL)));

end

function testMissingForcesThrowsError(testCase)
%TESTMISSINGFORCESTHROWSERROR An absent or empty forces.data is a hard
%error: it is the one truly required field.
verifyError(testCase,@() utils.buildDatlogFrameTable(struct()), ...
    'buildDatlogFrameTable:MissingForces');

datlogEmptyForces = struct();
datlogEmptyForces.forces.data = [];
verifyError(testCase, ...
    @() utils.buildDatlogFrameTable(datlogEmptyForces), ...
    'buildDatlogFrameTable:MissingForces');

end

function datlog = makeBaseDatlog()
%MAKEBASEDATLOG Build a minimal 5-frame synthetic datlog for testing.
%
%   Returns just datlog.forces.data (the only required field), so each
%   test augments it with whatever optional fields it needs to exercise.
%
% Inputs:
%   None
%
% Outputs:
%   datlog - struct with only forces.data populated
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, TESTBUILDDATLOGFRAMETABLE.

baseTime = datenum(2026,1,1,0,0,0);
dtDays   = 0.01/86400; % 10 ms between frames, in datenum days
frameNum = (101:105)';
uTime    = baseTime + (0:4)'*dtDays;
Rfz      = [-50;-60;-70;-80;-90];
Lfz      = [-55;-65;-75;-85;-95];
relTime  = (uTime - uTime(1))*86400;

datlog = struct();
datlog.forces.data = [frameNum uTime Rfz Lfz relTime];

end
