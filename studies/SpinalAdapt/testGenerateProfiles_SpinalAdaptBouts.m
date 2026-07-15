function tests = testGenerateProfiles_SpinalAdaptBouts()
%TESTGENERATEPROFILES_SPINALADAPTBOUTS Unit tests for the SpinalAdapt
%training-profile belt-acceleration structure.
%
%   Hardware-free validation that the belt-acceleration-smoothing
%   feature is wired correctly: for each training-profile MAT (baseOnly
%   = false), confirms accL/accR exist, match velL/velR in length, and
%   follow the intended per-bout pattern (accRampSmooth on ramp
%   strides, accDefault elsewhere). Also confirms baseline/calibration
%   profiles (baseOnly = true) omit accL/accR, so the controller falls
%   back to its own fixed default (unchanged legacy behavior). Profiles
%   are generated into a fresh temp directory per test, removed on
%   teardown. Run with:
%   runtests('testGenerateProfiles_SpinalAdaptBouts').
%
% Inputs:
%   None
%
% Outputs:
%   tests - test array produced by FUNCTIONTESTS
%
% Toolbox Dependencies: None
%
% See also GENERATEPROFILES_SPINALADAPTBOUTS.

tests = functiontests(localfunctions);

end

function setup(testCase)
%SETUP Generate both baseline and training profiles into a fresh temp
%directory (created by the generator itself) and register it for
%teardown.
profileDir = tempname();
slowSpeed  = 0.75;  % m/s; arbitrary test value
fastSpeed  = 1.5;   % m/s; arbitrary test value

generateProfiles_SpinalAdaptBouts(slowSpeed,fastSpeed,true,profileDir);
generateProfiles_SpinalAdaptBouts( ...
    slowSpeed,fastSpeed,false,profileDir,'R');

testCase.TestData.profileDir = profileDir;
testCase.addTeardown(@() rmdir(profileDir,'s'));

end

function testTrainingProfilesIncludeAccel(testCase)
%TESTTRAININGPROFILESINCLUDEACCEL Each training-condition MAT has
%accL/accR matching velL/velR in length.
names = {'FamBoutsSlow','FamBoutsFast','CtrlBouts','SplitBouts'};
for k = 1:numel(names)
    s = load(fullfile(testCase.TestData.profileDir,[names{k} '.mat']));
    verifyTrue(testCase,isfield(s,'accL'),[names{k} ' missing accL']);
    verifyTrue(testCase,isfield(s,'accR'),[names{k} ' missing accR']);
    verifyEqual(testCase,numel(s.accL),numel(s.velL));
    verifyEqual(testCase,numel(s.accR),numel(s.velR));
end

end

function testRampStridesUseSmoothAccel(testCase)
%TESTRAMPSTRIDESUSESMOOTHACCEL The first rampStrides of each bout use
%accRampSmooth; the remaining strides of the bout use accDefault.
% NOTE: these constants mirror generateProfiles_SpinalAdaptBouts; keep
% both in sync if the bout structure or smoothing values change.
rampStrides   = 10;    % strides; must match generateProfiles
boutLen       = 50;    % rampStrides + ssStrides + boutRestStrides
accRampSmooth = 0.3;   % m/s^2
accDefault    = 1.5;   % m/s^2

s = load(fullfile(testCase.TestData.profileDir,'CtrlBouts.mat'));
accPerBout = reshape(s.accL,boutLen,[])';   % bouts x strides-per-bout
verifyEqual(testCase,accPerBout(:,1:rampStrides), ...
    accRampSmooth*ones(size(accPerBout,1),rampStrides),'AbsTol',1e-9);
verifyEqual(testCase,accPerBout(:,rampStrides+1:end), ...
    accDefault*ones(size(accPerBout,1),boutLen-rampStrides), ...
    'AbsTol',1e-9);

end

function testAccLEqualsAccRForSplitBouts(testCase)
%TESTACCLEQUALSACCRFORSPLITBOUTS Ramp-stride indices are identical on
%both belts, independent of the fastLeg swap.
s = load(fullfile(testCase.TestData.profileDir,'SplitBouts.mat'));
verifyEqual(testCase,s.accL,s.accR);

end

function testBaselineProfilesOmitAccel(testCase)
%TESTBASELINEPROFILESOMITACCEL Constant-speed baseline profiles do not
%save accL/accR, so the controller falls back to its own default
%(unchanged legacy behavior).
s = load(fullfile(testCase.TestData.profileDir,'TMBaselineFast.mat'));
verifyFalse(testCase,isfield(s,'accL'));
verifyFalse(testCase,isfield(s,'accR'));

end
