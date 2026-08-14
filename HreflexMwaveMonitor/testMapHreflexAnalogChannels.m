function tests = testMapHreflexAnalogChannels()
%TESTMAPHREFLEXANALOGCHANNELS Unit tests for the BTK-independent
%EMG-sensor-to-muscle channel mapping.
%
%   Exercises MAPHREFLEXANALOGCHANNELS against a hand-built 'analogs'
%   struct (no BTK, no real C3D needed) using
%   GENERATEHREFLEXRECRUITMENTCURVES' own default sensor-order
%   convention ('EMG<n>' fields; muscle assignment is metadata external
%   to the file). This is the exact mapping logic an earlier version of
%   HREFLEXSOURCEREPLAYC3D got wrong (treating muscle labels like
%   'RSOL' as literal analog field names, which they never are) -- this
%   test would have caught that defect with no lab or BTK access. Run
%   with: runtests('testMapHreflexAnalogChannels').
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
% See also MAPHREFLEXANALOGCHANNELS, HREFLEXSOURCEREPLAYC3D.

tests = functiontests(localfunctions);

end

function testResolvesDefaultSensorMapChannelsBySensorNumber(testCase)
%TESTRESOLVESDEFAULTSENSORMAPCHANNELSBYSENSORNUMBER Confirms EMG
%channels are resolved via the sensor-number map, NOT by matching the
%muscle label as a literal field name (which they never are in a real
%C3D -- fields are named 'EMG<n>').
analogs = buildFakeAnalogs();
emgSensorMap = defaultEmgSensorMap();

[tapR,tapL,hR,hL,trigR,trigL] = ...
    hreflexMonitor.mapHreflexAnalogChannels(analogs,emgSensorMap,'SOL');

% sensor 1 = RTAP -> EMG1; sensor 7 = RSOL -> EMG7; etc. (see
% BUILDFAKEANALOGS: EMG<k> is filled with the constant value k)
verifyEqual(testCase,tapR,ones(5,1) * 1);
verifyEqual(testCase,tapL,ones(5,1) * 8);
verifyEqual(testCase,hR,ones(5,1) * 7);
verifyEqual(testCase,hL,ones(5,1) * 13);
verifyEqual(testCase,trigR,ones(5,1) * 101);
verifyEqual(testCase,trigL,ones(5,1) * 102);

end

function testMuscleSelectionChangesWhichSensorIsUsed(testCase)
%TESTMUSCLESELECTIONCHANGESWHICHSENSORISUSED Selecting 'MG' resolves
%to the gastrocnemius sensors (5, 11) instead of soleus (7, 13).
analogs = buildFakeAnalogs();
emgSensorMap = defaultEmgSensorMap();

[~,~,hR,hL,~,~] = ...
    hreflexMonitor.mapHreflexAnalogChannels(analogs,emgSensorMap,'MG');

verifyEqual(testCase,hR,ones(5,1) * 5);
verifyEqual(testCase,hL,ones(5,1) * 11);

end

function testMissingChannelReturnsEmpty(testCase)
%TESTMISSINGCHANNELRETURNSEMPTY A muscle label whose sensor's analog
%field is absent (here, the RSOL sensor's field is dropped) resolves
%to [] rather than erroring, so the caller (HREFLEXSOURCEREPLAYC3D)
%can raise one clear missing-channel error.
analogs = buildFakeAnalogs();
analogs = rmfield(analogs,'EMG7');   % drop the RSOL sensor
emgSensorMap = defaultEmgSensorMap();

[~,~,hR,~,~,~] = ...
    hreflexMonitor.mapHreflexAnalogChannels(analogs,emgSensorMap,'SOL');

verifyEqual(testCase,hR,zeros(0,0));

end

%% Local Functions

function analogs = buildFakeAnalogs()
%BUILDFAKEANALOGS Hand-built 'analogs' struct matching btkGetAnalogs'
%field-naming conventions ('EMG<n>', descriptive trigger names), with
%each EMG<n> channel filled with the constant value n so a test can
%confirm exactly which sensor's data was returned.
%
% Inputs:
%   None
%
% Outputs:
%   analogs - struct with fields EMG1..EMG16 and the two stimulator
%             trigger fields
%
% Toolbox Dependencies:
%   None

analogs = struct();
for sensorNum = 1:16
    analogs.(['EMG' num2str(sensorNum)]) = ones(5,1) * sensorNum;
end
analogs.Stimulator_Trigger_Sync_Right_Stimulator = ones(5,1) * 101;
analogs.Stimulator_Trigger_Sync_Left__Stimulator = ones(5,1) * 102;

end

function emgSensorMap = defaultEmgSensorMap()
%DEFAULTEMGSENSORMAP HREFLEXSOURCEREPLAYC3D's default sensor-order
%mapping (matches GENERATEHREFLEXRECRUITMENTCURVES' own default).
%
% Inputs:
%   None
%
% Outputs:
%   emgSensorMap - char; space-separated muscle labels in sensor order
%
% Toolbox Dependencies:
%   None

emgSensorMap = ['RTAP RTAD NA RPER RMG RLG RSOL LTAP LTAD LPER LMG ' ...
    'LLG LSOL NA NA sync1'];

end
