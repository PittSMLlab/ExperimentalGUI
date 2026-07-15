function report = probeViconDataStreamDevices(options)
%PROBEVICONDATASTREAMDEVICES Read-only Vicon DataStream device probe.
%
%   Opens a second, independent Vicon DataStream SDK client (the same
%   external interface NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO uses) and
%   enumerates every streamed device and its outputs, enabling ONLY
%   device data (EnableDeviceData()) -- never marker, segment, or
%   unlabeled-marker data, which this probe (and the monitor it gates)
%   never needs. This is the gating first deliverable for the near-
%   real-time H-reflex M-wave monitor: it confirms, on the machine the
%   monitor will run on, that the Delsys EMG channels and the Arduino
%   Stimulator_Trigger_Sync_* trigger channels are actually exposed as
%   live DataStream device outputs (not just written to the C3D), at
%   the expected ~2 kHz analog subsample rate, before any monitor code
%   is built against that assumption.
%
%   Read-only: connects, samples a handful of frames, prints a report,
%   and disconnects. Never opens the Arduino serial port, never sends a
%   treadmill or stimulation command, never writes to any datlog. Safe
%   to run alongside a live control/stimulation trial in a separate
%   MATLAB instance -- Nexus's DataStream server supports multiple
%   concurrent ClientPull clients.
%
%   NOTE ON UNVERIFIED SDK SURFACE: the value-retrieval call
%   (GetDeviceOutputValue) is already used elsewhere in this repo
%   (NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO's force-plate read), so it is
%   trusted as-is. The device/output ENUMERATION calls below
%   (GetDeviceCount, GetDeviceName, GetDeviceOutputCount,
%   GetDeviceOutputName) are standard, stable Vicon DataStream SDK
%   method names but are NOT otherwise used in this repo -- this probe
%   is their first exercise here. If any enumeration call errors on the
%   installed v1.11.0 SDK, consult that SDK's own MATLAB example
%   scripts under 'C:\Program Files\Vicon\DataStream SDK\Win64\' for
%   the exact method names and adjust here; do not guess further
%   without confirming against that reference.
%
% Inputs:
%   None
%
% Optional Name-Value Inputs:
%   hostName  - char; DataStream server address (default:
%               'localhost:801')
%   numFrames - number of frames to sample for the per-output
%               subsample-count check (default: 20)
%
% Outputs:
%   report - struct with fields:
%              deviceNames     - cell array of every streamed device
%                                 name
%              outputsByDevice - containers.Map, device name -> cell
%                                 array of that device's output names
%              subsampleCounts - containers.Map, 'device:output' ->
%                                 numel(Value) observed on the last
%                                 sampled frame (the per-frame
%                                 subsample count for that output)
%              hasEMG          - true if any output name contains
%                                 'EMG'
%              hasStimTrigger  - true if any output name contains
%                                 'Stimulator_Trigger_Sync'
%
% Toolbox Dependencies:
%   None (external: Vicon DataStream SDK v1.11.0, .NET assembly)
%
% See also RUNHREFLEXMWAVEMONITOR, NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO.

arguments
    options.hostName  (1,:) char = 'localhost:801'
    options.numFrames (1,1) double ...
        {mustBePositive,mustBeInteger} = 20
end

%% Connect a Second, Independent DataStream Client (Device Data Only)
% mirrors NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO's connection pattern
% (which()-first, addpath best-effort, uigetfile fallback) since the
% correct relative dotNET path is lab-PC-specific and unverified from
% this checkout.
addpath('..\..\dotNET');
dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
if isempty(dssdkAssembly)
    [file,path] = uigetfile('*.dll', ...
        'Select ViconDataStreamSDK_DotNET.dll');
    dssdkAssembly = fullfile(path,file);
end
NET.addAssembly(dssdkAssembly);

client = ViconDataStreamSDK.DotNET.Client();
client.Connect(options.hostName);
client.EnableDeviceData();     % device data ONLY -- see header note
client.SetStreamMode(ViconDataStreamSDK.DotNET.StreamMode.ClientPull);

%% Enumerate Devices and Their Outputs
client.GetFrame();     % a frame must be fetched before counts are valid
deviceCount = client.GetDeviceCount().DeviceCount;
deviceNames = cell(deviceCount,1);
outputsByDevice = containers.Map();

for dd = 1:deviceCount
    deviceInfo = client.GetDeviceName(dd);
    deviceNames{dd} = char(deviceInfo.DeviceName);
    outputCount = client.GetDeviceOutputCount( ...
        deviceNames{dd}).DeviceOutputCount;
    outputNames = cell(outputCount,1);
    for oo = 1:outputCount
        outputInfo = client.GetDeviceOutputName(deviceNames{dd},oo);
        outputNames{oo} = char(outputInfo.DeviceOutputName);
    end
    outputsByDevice(deviceNames{dd}) = outputNames;
end

%% Sample a Few Frames to Check the Per-Frame Subsample Count
% GetDeviceOutputValue is the confirmed-working call (see header note);
% its .Value is expected to be a numSubsamples x 1 array for channels
% sampled faster than the Vicon frame rate (e.g. 2 kHz EMG at 100 Hz
% frames -> ~20 subsamples/frame), matching the existing force-plate
% read's scalar .Value (1 subsample/frame at that device's rate).
subsampleCounts = containers.Map();
for ff = 1:options.numFrames
    client.GetFrame();
    for dd = 1:deviceCount
        outputNames = outputsByDevice(deviceNames{dd});
        for oo = 1:numel(outputNames)
            key = [deviceNames{dd} ':' outputNames{oo}];
            outputVal = client.GetDeviceOutputValue( ...
                deviceNames{dd},outputNames{oo});
            if ~strcmp(char(outputVal.Result),'Success')
                continue;   % skip a bad read; try again next frame
            end
            subsampleCounts(key) = numel(outputVal.Value);
        end
    end
end

%% Check for the Two Channel Families This Monitor Depends On
allOutputNames = {};
for dd = 1:deviceCount
    allOutputNames = [allOutputNames; ...
        outputsByDevice(deviceNames{dd})]; %#ok<AGROW>
end
hasEMG = any(contains(allOutputNames,'EMG'));
hasStimTrigger = any( ...
    contains(allOutputNames,'Stimulator_Trigger_Sync'));

%% Print Report
fprintf('=== Vicon DataStream Device Probe ===\n');
fprintf('Devices found: %d\n',deviceCount);
for dd = 1:deviceCount
    fprintf('  %s (%d outputs)\n',deviceNames{dd}, ...
        numel(outputsByDevice(deviceNames{dd})));
end
fprintf('EMG channels found: %d\n',hasEMG);
fprintf('Stimulator_Trigger_Sync_* channels found: %d\n', ...
    hasStimTrigger);
fprintf(['NOTE: expect ~20 subsamples/frame for 2 kHz EMG at 100 Hz ' ...
    'Vicon frames -- inspect report.subsampleCounts to confirm.\n']);

%% Disconnect (Read-Only; Never Sends Any Command)
client.Disconnect();

report.deviceNames     = deviceNames;
report.outputsByDevice = outputsByDevice;
report.subsampleCounts = subsampleCounts;
report.hasEMG          = hasEMG;
report.hasStimTrigger  = hasStimTrigger;

end
