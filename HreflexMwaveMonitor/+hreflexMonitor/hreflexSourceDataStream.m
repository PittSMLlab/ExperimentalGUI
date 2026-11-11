function source = hreflexSourceDataStream(leg, tapSensor, hSensor, options)
%HREFLEXSOURCEDATASTREAM Open a live Vicon source for one leg.
%
%   Connects an independent, device-data-only DataStream client and
% returns function handles that read one leg's proximal TA, H-reflex
% muscle, and stimulator trigger channels, one frame at a time. Never
% opens the Arduino serial port or writes to any datlog.
%
%   WHY SERVERPUSH: each subsample takes one SDK call of about 134 us on
% the lab PC, so two EMG channels take about 6 ms of the 10 ms frame, with
% occasional reads of 18 ms or more. On 2026-11-05, ClientPull and
% ClientPullPreFetch lost 3-9% of frames at every buffer size tried, while
% ServerPush with a 100-frame buffer lost none of 3037 (30 s, seated,
% one leg, no controller). Reading both legs in one client took about
% 14 ms per frame, too slow to keep up, so each leg gets its own instance.
%
%   The trigger is read once per frame, which still catches its 20 ms
% pulse. Channel names below were confirmed live on 2026-11-05. The live
% device is named 'Stimulator Trigger Signal', although the C3D export
% labels the same channels 'Stimulator Trigger Sync', and the left
% component name really does contain two spaces.
%
% Inputs:
%   leg       - char; 'R' or 'L'
%   tapSensor - EMG sensor number of this leg's proximal TA
%   hSensor   - EMG sensor number of this leg's H-reflex muscle
%
% Optional Name-Value Inputs:
%   hostName   - DataStream server address (default: 'localhost:801')
%   bufferSize - frames the SDK client queues (default: 100, about 1 s)
%
% Outputs:
%   source - struct with fields:
%              period    - EMG sampling period (s)
%              readFrame - handle; [hasFrame, frame] = source.readFrame(),
%                          where frame has fields frameNum, tap, h, trig
%              close     - handle; disconnects, ignoring teardown errors
%
% Toolbox Dependencies:
%   None (external: Vicon DataStream SDK .NET assembly)
%
% See also RUNHREFLEXMWAVEMONITORLIVE, ASSEMBLELIVECHUNK,
%   PROBEVICONDATASTREAMDEVICES, HREFLEXMAPPINGTOOL.

arguments
    leg       (1,1) char {mustBeMember(leg, {'R', 'L'})}
    tapSensor (1,1) double {mustBePositive, mustBeInteger}
    hSensor   (1,1) double {mustBePositive, mustBeInteger}
    options.hostName   (1,:) char = 'localhost:801'
    options.bufferSize (1,1) double {mustBePositive, mustBeInteger} = 100
end

nominalPeriodS  = 0.0005;  % s; HREFLEX.EXTRACTSNIPPETS assumes 2 kHz
periodTolFrac   = 0.01;    % allowed fractional difference from nominal
connectTimeoutS = 30;      % s; give up connecting after this long
connectRetryS   = 0.05;    % s; pause between connection attempts
deviceTimeoutS  = 15;      % s; wait for devices, as HREFLEXMAPPINGTOOL
channelTimeoutS = 10;      % s; then wait for this leg's channels
pollS           = 0.02;    % s; pause between frame polls

emgDevice  = 'EMG';
tapOutput  = sprintf('Sensor %d', tapSensor);
tapComp    = sprintf('IM EMG%d', tapSensor);
hOutput    = sprintf('Sensor %d', hSensor);
hComp      = sprintf('IM EMG%d', hSensor);
trigDevice = 'Stimulator Trigger Signal';
trigOutput = 'Electric Potential';
if leg == 'R'
    trigComp = 'Right Stimulator';
else
    trigComp = 'Left  Stimulator';   % NOTE: two spaces, as streamed
end

%% Connect a Device-Data-Only Client
sdkPath     = 'C:\Program Files\Vicon\DataStream SDK\Win64';
sdkAssembly = 'ViconDataStreamSDK_DotNET.dll';
asmPath = fullfile(sdkPath, sdkAssembly);
if exist(asmPath, 'file') ~= 2
    asmPath = which(sdkAssembly);
    if isempty(asmPath)
        [fileName, folder] = uigetfile('*.dll', ...
            'Select ViconDataStreamSDK_DotNET.dll');
        if isequal(fileName, 0)
            error('hreflexSourceDataStream:sdkNotFound', ...
                'SDK assembly not found; cannot continue.');
        end
        asmPath = fullfile(folder, fileName);
    end
end
NET.addAssembly(asmPath);
ok = ViconDataStreamSDK.DotNET.Result.Success;

client = ViconDataStreamSDK.DotNET.Client();
tConn = tic;
while ~client.IsConnected().Connected
    client.Connect(options.hostName);
    if toc(tConn) > connectTimeoutS
        error('hreflexSourceDataStream:connectTimeout', ...
            'Could not connect to Vicon at %s within %g s.', ...
            options.hostName, connectTimeoutS);
    end
    pause(connectRetryS);
end

try
    client.EnableDeviceData();     % device data ONLY
    client.SetBufferSize(options.bufferSize);
    client.SetStreamMode(ViconDataStreamSDK.DotNET.StreamMode.ServerPush);

    %% Wait for Devices, Then This Leg's Channels
    % device metadata appears only some frames after the first GetFrame()
    tWait = tic;
    while client.GetFrame().Result ~= ok ...
            || double(client.GetDeviceCount().DeviceCount) == 0
        if toc(tWait) > deviceTimeoutS
            error('hreflexSourceDataStream:noDevices', ...
                ['No devices appeared within %g s. Confirm Nexus is ' ...
                'in Live mode and streaming.'], deviceTimeoutS);
        end
        pause(pollS);
    end

    tWait = tic;
    while true
        client.GetFrame();
        tapInfo = client.GetDeviceOutputSubsamples( ...
            emgDevice, tapOutput, tapComp);
        hInfo = client.GetDeviceOutputSubsamples( ...
            emgDevice, hOutput, hComp);
        trigInfo = client.GetDeviceOutputSubsamples( ...
            trigDevice, trigOutput, trigComp);
        if tapInfo.Result == ok && hInfo.Result == ok ...
                && trigInfo.Result == ok ...
                && double(tapInfo.DeviceOutputSubsamples) >= 1
            break;
        end
        if toc(tWait) > channelTimeoutS
            error('hreflexSourceDataStream:noChannels', ...
                ['Could not resolve %s/%s, %s/%s, or %s/%s/%s. Check ' ...
                'the sensor numbers and the Nexus profile, and run ' ...
                'PROBEVICONDATASTREAMDEVICES to list live names.'], ...
                tapOutput, tapComp, hOutput, hComp, trigDevice, ...
                trigOutput, trigComp);
        end
        pause(pollS);
    end

    %% Confirm the Sampling Rate the Offline Functions Assume
    frameRateHz = double(client.GetFrameRate().FrameRateHz);
    numEmgPerFrame = double(tapInfo.DeviceOutputSubsamples);
    period = 1 / (frameRateHz * numEmgPerFrame);
    if abs(period - nominalPeriodS) > periodTolFrac * nominalPeriodS
        error('hreflexSourceDataStream:badRate', ...
            ['EMG streams at %.1f Hz (%.1f Hz frames, %d subsamples), ' ...
            'but the +Hreflex functions assume 2000 Hz.'], 1 / period, ...
            frameRateHz, numEmgPerFrame);
    end
    period = nominalPeriodS;

    %% Discard Frames Queued Before the Monitor Was Ready
    for ff = 1:options.bufferSize
        client.GetFrame();
    end
catch ME
    closeClient();
    rethrow(ME);
end

source.period    = period;
source.readFrame = @readFrame;
source.close     = @closeClient;

    function [hasFrame, frame] = readFrame()
    %READFRAME Read this leg's channels from the next queued frame.
    %
    % Inputs:
    %   None
    %
    % Outputs:
    %   hasFrame - false if no frame or channel data was available
    %   frame    - struct with frameNum, tap, h, trig; [] if ~hasFrame
    %
    % Toolbox Dependencies:
    %   None (external: Vicon DataStream SDK .NET assembly)

    hasFrame = false;
    frame = [];
    if client.GetFrame().Result ~= ok
        return;
    end
    numEmg = double(client.GetDeviceOutputSubsamples( ...
        emgDevice, tapOutput, tapComp).DeviceOutputSubsamples);
    if numEmg < 1
        return;
    end

    frame.frameNum = double(client.GetFrameNumber().FrameNumber);
    frame.tap = nan(numEmg, 1);
    frame.h   = nan(numEmg, 1);
    for sub = 0:numEmg - 1      % subsample index is zero-based
        frame.tap(sub + 1) = double(client.GetDeviceOutputValue( ...
            emgDevice, tapOutput, tapComp, uint32(sub)).Value);
        frame.h(sub + 1) = double(client.GetDeviceOutputValue( ...
            emgDevice, hOutput, hComp, uint32(sub)).Value);
    end
    frame.trig = double(client.GetDeviceOutputValue( ...
        trigDevice, trigOutput, trigComp, uint32(0)).Value);
    hasFrame = true;

    end

    function closeClient()
    %CLOSECLIENT Disconnect from Vicon, ignoring teardown errors.
    %
    % Inputs:
    %   None
    %
    % Outputs:
    %   None
    %
    % Toolbox Dependencies:
    %   None (external: Vicon DataStream SDK .NET assembly)

    try
        if client.IsConnected().Connected
            client.Disconnect();
        end
    catch
        % ignore errors during teardown
    end

    end

end
