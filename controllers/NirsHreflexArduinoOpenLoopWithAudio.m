function [RTOTime,LTOTime,RHSTime,LHSTime,commSendTime,commSendFrame] = ...
    NirsHreflexArduinoOpenLoopWithAudio(velL,velR,FzThreshold, ...
    profilename,numAudioCountDown,isCalibration,oxysoft_present, ...
    hreflex_present,stimL,stimR)
%NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO Open loop split-belt controller with
%fNIRS event markers, audio feedback, and Arduino-timed H-reflex
%stimulation.
%
%   This is adapted from the open loop controller with audio feedback.
%   NIRS events for tied, ramp, split, rest (optional, if exists, always
%   rest for a fixed ~10 s silent duration, see restSilentSec) are
%   added. When to log a NIRS event is determined by parsing velL/velR
%   (0 speeds are treated as rest; the parse also finds tied, ramp,
%   split, and post segments).
%
%   H-reflex stimulation timing is split between this controller and the
%   Arduino running
%   HreflexStimArduino/triggerStimWithGaitStateMachine_SpeedIndependent/.
%   The Arduino owns the precise 50%-single-stance pulse timing: it runs
%   its own gait-event state machine and fires the stimulus locally. This
%   controller sends serial command 0 once (before the main loop) to
%   start the Arduino's state machine, sends a per-stride gate byte (1 =
%   stim left, 2 = stim right) during the double support phase
%   immediately preceding single-stance onset to flag which leg to
%   stimulate, and sends command 3 (in the closing routine) to stop the
%   Arduino's state machine. Sending during the preceding double support
%   (rather than at onset) only widens the margin before the Arduino's
%   50% trigger; the Arduino still owns exactly when the pulse fires. Do
%   not change these command bytes without re-uploading compatible
%   Arduino firmware.
%
%   --- Doc from the open loop controller (controlSpeedWithSteps_edit1
%   with audio countdown) ---
%   This function takes two vectors of speeds (one for each treadmill
%   belt) and successively updates the belt speed upon ipsilateral
%   toe-off. The function only updates the belts alternately, i.e., a
%   single belt speed cannot be updated twice without the other being
%   updated. The first value for velL and velR is the initial desired
%   speed, and new speeds will be sent for the following N-1 steps,
%   where N is the length of velL.
%
%   Feature Improvement TODO: at this point, the arguments isCalibration,
%   oxysoft_present, hreflex_present are not really accessible when going
%   through the UI flow of using AdaptationGUI; they are only settable
%   via code and setting params to be global.
%
% Inputs:
%   velL - Nx1 left belt speed profile (mm/s); NaN entries are
%          self-paced strides
%   velR - Nx1 right belt speed profile (mm/s); NaN entries are
%          self-paced strides
%   FzThreshold - force-plate stance threshold (N); overridden to a
%          robust hard floor inside the function regardless of input
%   profilename - name used for the saved datlog filename
%   numAudioCountDown - stride indices at which to play a 3-2-1 audio
%          countdown before a speed change, terminated by -1 (count down
%          at treadmill start/stop only)
%   isCalibration - true for an H-reflex calibration trial (disables
%          fNIRS, plays per-side calibration audio instead of NIRS cues)
%   oxysoft_present - true to connect to Oxysoft fNIRS software
%   hreflex_present - true to open the Arduino serial port and run
%          H-reflex stimulation
%   stimL - Nx1 logical/numeric flag of which left strides to stimulate;
%          empty selects every 10th stride
%   stimR - Nx1 logical/numeric flag of which right strides to
%          stimulate; empty selects every 10th stride
%
% Outputs:
%   RTOTime - right toe-off timestamps (datenum) per stride
%   LTOTime - left toe-off timestamps (datenum) per stride
%   RHSTime - right heel-strike timestamps (datenum) per stride
%   LHSTime - left heel-strike timestamps (datenum) per stride
%   commSendTime - treadmill command send timestamps (clock vectors)
%   commSendFrame - frame numbers at treadmill command send
%
% Toolbox Dependencies: None
%
% See also NIRSHREFLEXOPENLOOPWITHAUDIO, HREFLEXOGWITHAUDIO, GETPAYLOAD.

arguments
    % FzThreshold has no default here even though the body always
    % overrides it to 100 a few lines down: it must stay required because
    % 'profilename'/'numAudioCountDown' are required positional arguments
    % that follow it (required arguments cannot follow optional ones).
    velL              (:,1) double
    velR              (:,1) double
    FzThreshold       (1,1) double
    profilename       (1,:) char
    numAudioCountDown (1,:) double
    isCalibration     (1,1) logical = false
    oxysoft_present   (1,1) logical = true
    hreflex_present   (1,1) logical = true
    stimL             (:,1) double = []
    stimR             (:,1) double = []
end

% argument-dependent defaults: an empty stimL/stimR means "no explicit
% per-stride stim schedule was provided", handled below via stimInterval
if isempty(stimL)
    stimL = zeros(numel(velL),1);
end

if isempty(stimR)
    stimR = zeros(numel(velR),1);
end

%% Open Arduino Serial Communication (If H-reflex Is Enabled)
%These parameters should ONLY BE CHANGED IF YOU KNOW WHAT YOU ARE DOING.
% Arduino serial command bytes; one uint8 per command (write(...,'uint8')
% below). The byte VALUES are frozen with the firmware's
% processSerialCommands() -- see HreflexStimArduino/README.md -- but the
% WIRE WIDTH matters too: a wider precision (e.g., 'int16') pads a
% trailing zero byte that the firmware reads as a spurious command 0
% (resetStateMachine) one loop pass after every real command.
cmdArduinoStart = 0; % reset counters and run the gait state machine
cmdArduinoStimL = 1; % gate: stimulate left leg this stride
cmdArduinoStimR = 2; % gate: stimulate right leg this stride
cmdArduinoStop  = 3; % stop the gait state machine
percentSS2Stim = 0.50; % target fraction of single stance for the stim (diagnostic only; Arduino applies its own copy of this target)
alpha          = 0.7;  % MATLAB-side smoothing factor for estSSL/R (diagnostic only, 0 < alpha <= 1); matches the Arduino firmware's alpha so the logged estSS mirrors the device
estSSLInit     = 396.6; % initial single-stance duration estimate (ms); from Liu et al. 2014 normative gait data, see Arduino sketch header for derivation
estSSRInit     = 396.6;
% physiologic single-stance duration window (ms) for the EWMA outlier
% clamp; mirrors the Arduino durSSMinValid/durSSMaxValid so the logged
% estSS keeps tracking the device. Tunable starting values (see sketch).
durSSMinValidMs = 100;  % reject < 100 ms (double-detect / debounce floor)
durSSMaxValidMs = 1000; % reject > 1000 ms (missed event / rest artifact)

if hreflex_present
    try
        % configure and open serial port communication with Arduino
        fprintf('Opening Arduino serial port...\n');
        portArduino = serialport('COM4',115200);
        fprintf('Arduino serial port opened successfully.\n');
    catch ME
        warning(ME.identifier,'Failed to open Arduino serial port: %s', ...
            ME.message);
        % if this is the case, check that all Arduino software is closed
        % set to false to bypass stimulation if Arduino connection fails
        hreflex_present = false;
        return;
    end

    if isCalibration        % if H-reflex calibration trial, ...
        oxysoft_present = false;    % disable fNIRS in H-reflex calibration

        % load calibration audio for left and right stimulation events
        [audio_data,audio_fs] = audioread('L.mp3');
        CalibAudioL = audioplayer(audio_data,audio_fs);
        [audio_data,audio_fs] = audioread('R.mp3');
        CalibAudioR = audioplayer(audio_data,audio_fs);
    end

    if any(stimL) || any(stimR)
        % an explicit per-stride stim schedule was provided
        stimInterval = nan;
    else
        stimInterval = 10;  % stimulate every 10 strides
    end
    canStim = false; % latches true at the start of the preceding double support; allows exactly one gate send per stance
    gateSentTimeR = NaN; % now() when the R gate was sent; pending until single-stance R onset for the lead-time diagnostic
    gateSentTimeL = NaN;
    estSSL = estSSLInit; % running estimate of left single-stance duration (ms, diagnostic only)
    estSSR = estSSRInit;
    durSSL = estSSLInit; % most recent measured left single-stance duration (ms); seeded with the normative estimate until the first stride completes
    durSSR = estSSRInit;
    stimDelayL = estSSLInit * percentSS2Stim; % diagnostic-only target delay (ms), logged alongside each stim
    stimDelayR = estSSRInit * percentSS2Stim;
    echoBuf = ''; % partial serial line carried across iterations for the device stim echo
    % ardStep regression sentinel: an Arduino-side step counter that ever
    % decreases means the firmware's state machine reset mid-trial (the
    % symptom of the 2026-08 missed/wrong-stride stim encoding bug -- see
    % CLAUDE.md's H-reflex timing contract). Warn once per leg so a fault
    % cannot spam the control loop.
    prevArdStepL = 0;
    prevArdStepR = 0;
    ardStepWarnedL = false;
    ardStepWarnedR = false;
end

%% Load GUI Handle and Audio Files for Countdown
global PAUSE STOP
STOP = false;

if ~ismember(-1,numAudioCountDown)  % if '-1' not included, throw an error
    error('Incorrect input: -1 must be included in numAudioCountDown.');
end

if numAudioCountDown    % copied from open loop audiocountdown controller
    % TMStartIn3/TMStopIn3 (treadmill start/stop 3-2-1 countdown) are not
    % loaded: bout start/stop now use the 'walk'/'stop'/
    % 'silentlyCountForward' cues from the instructions map (see below)
    % instead of a countdown.
    % 2/1/now/TMChangeIn3 remain for the mid-trial speed-change countdown
    % branch, which this protocol does not reach (numAudioCountDown is
    % the scalar -1) but which other profiles may still use.
    [audio_data,audio_fs] = audioread('2.mp3');
    AudioCount2 = audioplayer(audio_data,audio_fs);
    [audio_data,audio_fs] = audioread('1.mp3');
    AudioCount1 = audioplayer(audio_data,audio_fs);
    [audio_data,audio_fs] = audioread('now.mp3');
    AudioNow = audioplayer(audio_data,audio_fs);
    [audio_data,audio_fs] = audioread('TMChangeIn3.mp3');
    AudioTMChange3 = audioplayer(audio_data,audio_fs);
end

% get handle to the GUI so displayed data can be updated
ghandle = guidata(AdaptationGUI);

%% Set Up NIRS Communication
% Pop up window to confirm parameter setup, which is helpful in case
% debugging happened between experiment session to avoid mistakenly
% forgetting to log fNIRS data.
button = questdlg(['Confirm that NIRS is recording and ' ...
    '''oxysoft_present'' is true.']);
if ~strcmp(button,'Yes')
    return;     % abort starting the trial
end

Oxysoft = NaN;  % initialize to 'NaN' unless present
if oxysoft_present
    Oxysoft = actxserver('OxySoft.OxyApplication');
end

% connect to Oxysoft software
disp('Initial Setup');
%Event code hardcoded: I-connected, O-Relax, T-TMStopCountDown, R-Rest
%Event code from initial letter in nirsEventNames: A-AccRamp (to start),
%S-Split, M-Mid, P-PostTied, D-DccRamp2Split
%set up audio players
audioids = {'relax','stop','silentlyCountForward','walk'};
instructions = containers.Map();
for ii = 1:length(audioids)
    [audio_data,audio_fs] = audioread([audioids{ii} '.mp3']);
    instructions(audioids{ii}) = audioplayer(audio_data,audio_fs);
end

%this should be changed if the protocol is changing to no ramp, straight to
%start, then the event would be 'Mid'
% Both bout-start ramp labels play the same "Walk" cue: tied bouts ramp
% via 'AccRamp', split bouts ramp via 'DccRamp2Split' (see
% PARSEEVENTSFROMSPEEDS). Mapping both here fixes split bouts that were
% previously silent at the start of every bout after the first.
tmStartEventNames = {'AccRamp', 'DccRamp2Split'};
for ii = 1:numel(tmStartEventNames)
    instructions(tmStartEventNames{ii}) = instructions('walk');
end

%% Parse Speed Profiles for NIRS Event Logging
[nirsEventSteps,nirsEventNames] = ...
    parseEventsFromSpeeds(velL(:,1),velR(:,1));
restIdx = strcmp(nirsEventNames,'Rest');
%this is safe to call even if there is no rest in the protocol.
restSteps = nirsEventSteps(restIdx);

%% Ask User for Train Index
% Number of bouts in this profile equals the number of rest events (one
% rest pad follows each bout; see GENERATEPROFILES_SPINALADAPTBOUTS): 5
% bouts for a familiarization block, 10 bouts for a main Control/Split
% block. Deriving nBouts here (rather than hard-coding it) keeps the
% dialog range correct for whichever block is loaded.
nBouts = length(restSteps);
if nBouts > 1 %at least 2 rest exist, then ask which one to start from.
    prompt = sprintf(['Which bout would you like to start from ' ...
        '(valid entries: 1-%d; press Enter to start from the ' ...
        'beginning)? '], nBouts);
    trainIdx = inputdlg(prompt, 'Start Bout', 1, {'1'});
    if isempty(trainIdx)    % Cancel/Escape pressed
        return;             % abort the trial
    end
    trainIdx = str2double(trainIdx{1});
    if isnan(trainIdx) || trainIdx ~= fix(trainIdx)
        trainIdx = 1;                            % invalid: default
    else
        trainIdx = min(max(trainIdx, 1), nBouts); % clamp to valid range
    end
    disp(['Starting the Split trainIdx from ' num2str(trainIdx)]);
    if trainIdx > 1     % skipping some beginning trains
        restSteps = restSteps(trainIdx:end);
        velL = velL(restSteps(1):end,:);    % only keep portions of profile that's after the starting rest.
        velR = velR(restSteps(1):end,:);
        stimL = stimL(restSteps(1):end,:); %only keep portions of profile that's after the starting rest.
        stimR = stimR(restSteps(1):end,:);
        % parse new 'velL' and 'velR' again to get correct event steps and index
        [nirsEventSteps,nirsEventNames] = parseEventsFromSpeeds(velL(:,1),velR(:,1));
        restIdx = strcmp(nirsEventNames,'Rest');
        restSteps = nirsEventSteps(restIdx); % this is safe to call even if there is no rest in the protocol.
        manualLoadProfile([],[],ghandle,[],velL(:,1)/1000, velR(:,1)/1000);
    end
    trainIdx = trainIdx - 1; % will be used later for audioCue event suffix (typically starts with Rest1, if entered start from TrainIdx3, should log Rest 3 (nextRest=1 + train3-1)
else
    trainIdx = 0; % will be used later for audioCue event suffix (typically Rest1+0, this is initialized to avoid calling a non-exist variable later)
end

nirsEventSteps(restIdx) = []; % remove rest from this array
nirsEventNames(restIdx) = [];
need2LogEvent = false; % initialize to false;
if ~isempty(restSteps)
    need2LogEvent = true;
end
nextRestIdx = 1;
startCueSettleSec = 1; % s; fixed margin added after the "walk" start cue
% finishes playing and before the belts begin accelerating, so the
% participant has a moment to brace beyond the cue's own (short) length
restSilentSec = 10; % s; target SILENT counting window, i.e., time after
% the 'silentlyCountForward' audio cue (silentlyCountForward.mp3) before
% belts resume; applies to every run of this controller, including
% fNIRS/H-reflex sessions
stopCuePlayer  = instructions('stop');
stopCueSec     = stopCuePlayer.TotalSamples / stopCuePlayer.SampleRate;
countCuePlayer = instructions('silentlyCountForward');
countCueSec    = countCuePlayer.TotalSamples / countCuePlayer.SampleRate;
% the rest handler below plays 'stop', blocks for stopCueSec so the two
% cues don't overlap, then plays 'silentlyCountForward' and starts the
% rest timer together with THAT cue — padding the target by only the
% second cue's own length keeps the silent remainder at ~restSilentSec
% after counting instructions finish
restDuration = restSilentSec + countCueSec;

if ~isempty(nirsEventSteps)
    need2LogEvent = true;
end
nextNirsEventIdx = 1;

%% Initialize Data Logging Structure (Preallocated)
datlog = struct();
buildTime = datetime('now'); % timestamp
% datenum() is itself flagged (DATNM) but is the only way to keep
% buildtime's stored type an unchanged serial date number; suppressed
% rather than changed, same as the hot-path now()/clock storage sites
% below -- storage-format modernization deferred to prompt 18
% (coordinated w/ labTools).
datlog.buildtime = datenum(buildTime); %#ok<DATNM>
temp = char(buildTime,'yyyy_MM_dd_HH_mm_ss');
[d,n] = fileparts(which(mfilename));
savename = fullfile(d,'..','datlogs',[temp '_' profilename]);
set(ghandle.sessionnametxt,'String',[temp '_' n]);
datlog.session_name = savename;
datlog.errormsgs = {};
datlog.messages = cell(1,2);
datlog.framenumbers.header = {'frame #','U Time','Relative Time'};
numFramesEst = 300 * length(velR) + 7200;
datlog.framenumbers.data = nan(numFramesEst,2);
datlog.forces.header = {'frame #','U Time','Rfz','Lfz','Relative Time'};
datlog.forces.data = nan(numFramesEst,4); %check file cleaning, how you initialized it should be how you clean it up in the end
%e.g., if you initialize nan, when saving datlog, should check for first
%row of nan and remove all entries after to have a clean datlog and have
%relative time calculated properly. If you initialize to 0, when saving
%datlog, should check for first row of 0.
datlog.stepdata.header = {'Step#','U Time','frame #','Relative Time'};
datlog.stepdata.RHSdata = zeros(numel(velR)+50,3); % empty cell theoretically big enough to house all the steps taken
datlog.stepdata.RTOdata = zeros(numel(velR)+50,3);
datlog.stepdata.LHSdata = zeros(numel(velL)+50,3);
datlog.stepdata.LTOdata = zeros(numel(velL)+50,3);
datlog.inclineang = [];
datlog.speedprofile.velL = velL(:,1);
datlog.speedprofile.velR = velR(:,1);
datlog.TreadmillCommands.header = {'RBS','LBS','angle','U Time','Relative Time'};
datlog.TreadmillCommands.read = nan(numFramesEst,4);
datlog.TreadmillCommands.sent = nan(numFramesEst,4);
datlog.audioCues.start = [];    % initialize audioCue log fields
datlog.audioCues.audio_instruction_message = {};
datlog.stim.header = {'Step#','StimDelayTarget(ms)','GateSendTime(SerialDate#)'};
datlog.stim.L = [];
datlog.stim.R = [];
% Device stim echo (additive; NOT consumed by labTools/SyncDatalog).
% deviceEcho holds one row per pulse the Arduino actually delivered;
% deviceDrop holds one row per gate the firmware dropped instead of
% firing (too late relative to target, or its single-stance onset never
% arrived -- see triggerStimWithGaitStateMachine_SpeedIndependent.ino's
% triggerStimulation()). Both are echoed back over serial as timing
% ground truth (see firmware echoStimRecord) and share one schema.
% Columns:
%   leg       - 1 = left, 2 = right
%   ardStep   - Arduino-side ipsilateral step counter at the record
%   matStep   - MATLAB-side step counter when the echo was drained
%   stimMs    - Arduino millis() time the pulse fired (deviceEcho) or the
%               drop was detected (deviceDrop)
%   toRefMs   - Arduino millis() of the contralateral toe-off reference
%   estSSms   - Arduino single-stance estimate at the record (ms)
%   dtStimMs  - stimMs - toRefMs, i.e., elapsed time into single stance
%   durSSms   - MATLAB-measured single-stance duration used as denominator
%   pctSS     - 100 * dtStimMs / durSSms, the actual (or attempted, for a
%               drop) % of single stance
%   matTimeSerial - now() when MATLAB drained this record; lets the
%               Arduino millis() clock be regressed onto the MATLAB/Vicon
%               clock offline to attribute a record to a definite stride
% NOTE: pctSS mixes an Arduino-detected toe-off (numerator) with a
% MATLAB-detected single-stance duration (denominator), so it carries a
% small cross-detector error and is an online gross-error check only. The
% Vicon analog sync pulse (Arduino pins 11/12) recorded on the same clock
% as the force-plate events is the gold-standard acceptance measurement.
datlog.stim.deviceEcho.header = {'leg','ardStep','matStep','stimMs', ...
    'toRefMs','estSSms','dtStimMs','durSSms','pctSS','matTimeSerial'};
datlog.stim.deviceEcho.data = [];
datlog.stim.deviceDrop.header = datlog.stim.deviceEcho.header;
datlog.stim.deviceDrop.data = [];
% Loop-timing diagnostics (additive; NOT consumed by labTools/SyncDatalog).
% loopSegMs columns: [iterTotal, drawnow/GUI, Vicon read+interop, control+
% stim], all in ms. gateLeadMs* record (single-stance onset time - gate
% send time), in ms: POSITIVE means the gate reached the Arduino that
% many ms BEFORE onset (the intended, safe margin); a value near zero or
% negative flags the rare double-support-skip edge case where the gate
% could only be sent at onset itself.
datlog.diagnostics.header = {'iterTotalMs','guiMs','viconMs','ctrlMs'};
datlog.diagnostics.loopSegMs = zeros(numFramesEst,4);
datlog.diagnostics.gateLeadMsL = [];
datlog.diagnostics.gateLeadMsR = [];
% NOTE: TreadmillCommands.read columns 1-2 (RBS, LBS) are the Bertec's
% own reported belt speeds (not just what was commanded); .sent holds
% what was actually commanded. For a consolidated per-frame view joining
% these with forces, gait events, and stim gate sends, see
% utils.buildDatlogFrameTable(datlog) -- a read-side helper, not stored
% here, so it adds nothing to the saved .mat file.
% NOTE: every stored "U Time"/timestamp column below (framenumbers,
% forces, stepdata, TreadmillCommands, stim GateSendTime, messages,
% RTOTime/LTOTime/RHSTime/LHSTime, commSendTime) still uses now()/clock
% intentionally: they are serial date numbers consumed as datenum
% arithmetic elsewhere (e.g. the durSSL/durSSR and gateLeadMs
% computations), and converting the call itself to datetime() would
% change the stored type or add a per-frame datetime construction cost
% on this hot loop. Modernizing the storage format is deferred to a
% coordinated ExperimentalGUI + labTools change; the %#ok suppressions
% below intentionally silence the editor warning until then.

%do initial save
try
    save(savename,'datlog');
catch ME
    disp(ME);
end

%% Force Plate Threshold Setup
if FzThreshold < 30
    datlog.messages{end+1,1} = 'Warning: Fz threshold too low to be robust to noise, using 30N instead';
    disp('Warning: Fz threshold too low to be robust to noise, using 30N instead');
end

forcePlateRobustThreshold = 100; % N; force plates are noisy (+-60N), so this floor is always imposed below
FzThreshold = forcePlateRobustThreshold;
datlog.messages{end+1,1} = 'Fz threshold is set to 100N for robust noise handling';
disp('Fz threshold is set to 100N for robust noise handling');

% check that velL and velR are of equal length
N = length(velL) + 1;
if length(velL) ~= length(velR)
    disp('WARNING: Velocity vectors of different length!');
    datlog.messages{end+1,1} = 'Velocity vectors of different length selected';
end

%% Initialize Nexus & Treadmill Communications
try
    HostName = 'localhost:801';
    addpath('..\dotNET');
    dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
    if isempty(dssdkAssembly)
        [file,path] = uigetfile('*.dll');
        dssdkAssembly = fullfile(path,file);
    end

    NET.addAssembly(dssdkAssembly);
    MyClient = ViconDataStreamSDK.DotNET.Client();
    MyClient.Connect(HostName);
    MyClient.EnableSegmentData();
    MyClient.EnableMarkerData();
    MyClient.EnableUnlabeledMarkerData();
    MyClient.EnableDeviceData();
    MyClient.SetStreamMode(ViconDataStreamSDK.DotNET.StreamMode.ClientPull);
catch ME
    disp('Error creating Nexus Client Object/communications. See datlog for details.');
    datlog.errormsgs{end+1} = 'Error creating Nexus Client Object/communications.';
    datlog.errormsgs{end+1} = ME;   % store specific error
    disp(ME);
end

try
    fprintf('Open TM Comm. Date Time: %s\n',char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
    t = openTreadmillComm();
    fprintf('Done Opening. Date Time: %s\n',char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
catch ME
    disp('Error creating TCP connection to Treadmill. See datlog for details.');
    datlog.errormsgs{end+1} = 'Error creating TCP connection to Treadmill.';
    datlog.errormsgs{end+1} = ME;
    disp(ME);
end

try     % so that if something fails, communications are closed properly
    MyClient.GetFrame();
    datlog.messages(end+1,:) = {'Nexus and Bertec Interfaces initialized: ',now()}; %#ok<TNOW1>

    % initialize trial variables
    new_stanceL = false;
    new_stanceR = false;
    phase = 0; % 0 = Double Support, 1 = single L support, 2 = single R support
    LstepCount = 1;
    RstepCount = 1;
    RTOTime(N) = now(); %#ok<TNOW1>
    LTOTime(N) = now(); %#ok<TNOW1>
    RHSTime(N) = now(); %#ok<TNOW1>
    LHSTime(N) = now(); %#ok<TNOW1>
    commSendTime = zeros(2*N-1,6);
    commSendFrame = zeros(2*N-1,1);

    [RBS,LBS,cur_incl] = readTreadmillPacket(t); % read treadmill incline angle
    lastRead = tic; % timer since last treadmill read (throttle below)
    datlog.inclineang = cur_incl;
    read_theta = cur_incl;

    % Nimbus start sync
    % create file on hard drive, then delete later after task is finished
    tSync = tic;
    syncname = fullfile(tempdir,'SYNCH.dat');
    fid = fopen(syncname,'wb');
    fclose(fid);
    fprintf('Sync file creation time (s): %.3f\n',toc(tSync));

    % audio start cue
    % if no rest (regular adapt block) or 1st stride speed is non 0, start with the "walk" cue.
    % suppressFirstStartCue latches true only when this cue plays, so the
    % upcoming bout-1 ramp event below (AccRamp / DccRamp2Split) doesn't
    % announce "walk" a second time; a resumed bout (trainIdx > 1) starts
    % on a rest pad instead, skips this block, and gets its start cue
    % from the ramp event only.
    suppressFirstStartCue = false;
    if (isempty(restSteps) || velL(1,1) ~=0) && numAudioCountDown %No rest, will start right away. Play the walk cue.
        fprintf('Ready to walk. Date Time: %s\n',char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
        walkCuePlayer = instructions('walk');
        play(walkCuePlayer);
        pause(walkCuePlayer.TotalSamples / walkCuePlayer.SampleRate ...
            + startCueSettleSec);
        suppressFirstStartCue = true;
        % log it without saying "walk" again.
        datlog = nirsEvent('Mid_noaudio','M',['Mid' num2str(nextRestIdx-1)],instructions,datlog,Oxysoft,oxysoft_present);
    end

    % Send first speed command and log it. Both belts are stationary
    % and both feet are planted (no gait cycle running yet) here, so
    % this is a moment acceleration is felt directly through both legs
    % -- the same condition recurs whenever a belt resumes from a rest
    % break mid-trial (see accInitial's other use in the main loop
    % below). Every other speed change is sent on the ipsilateral
    % swinging (unloaded) foot instead, where accel magnitude has no
    % tactile effect as long as target speed is reached before the
    % next heel strike, so only these from-a-dead-stop commands use
    % the gentler accInitial.
    accInitial = 500; % mm/s^2; about 1/3 of acc below, to smooth the
    % moments both feet are planted on stationary belts
    % (empirically-tuned starting value)
    acc = 1500; %used to be 3500, made it smaller for start to be more smooth, 1500 would achieve 1.5m/s in 1second, which is beyond the expected max speed we will ever use in this protocol.
    payload = getPayload(velR(1,1),velL(1,1),accInitial, ...
        accInitial,cur_incl);
    sendTreadmillPacket(payload,t);
    datlog.TreadmillCommands.firstSent = [velR(RstepCount,1) ...
        velL(LstepCount,1) accInitial accInitial cur_incl now()]; %#ok<TNOW1>
    commSendTime(1,:) = clock; %#ok<CLOCK>
    datlog.TreadmillCommands.sent(1,:) = [velR(RstepCount,1) velL(LstepCount,1) cur_incl now()]; %#ok<TNOW1>
    datlog.messages(end+1,:) = {'First speed command sent',now()}; %#ok<TNOW1>
    datlog.messages{end+1,1} = ['Lspeed = ' num2str(velL(LstepCount,1)) ', Rspeed = ' num2str(velR(RstepCount,1))];

    %% Start Arduino State Machine
    % Send this right before walking starts (not immediately after opening
    % the serial port) so the Arduino's step/phase counters reset close to
    % actual walking onset instead of sitting idle through NIRS setup and
    % the audio countdown above, which could otherwise skew the first
    % estSSL/estSSR estimate with spurious phase transitions.
    if hreflex_present
        try
            fprintf('Sending start command to Arduino state machine...\n');
            write(portArduino,cmdArduinoStart,'uint8'); % reset & start
            % Clear any bytes left in the OS input buffer from a prior
            % session before the loop starts draining stim echoes; command
            % 0 produces no echo, so nothing of ours is discarded here.
            flush(portArduino,'input');
            fprintf('Start command sent successfully.\n');
        catch ME
            warning(ME.identifier,['Failed to send start command to ' ...
                'Arduino: %s'],ME.message);
        end
    end

    %% Main Loop
    old_velR = libpointer('doublePtr',velR(1,1));
    old_velL = libpointer('doublePtr',velL(1,1));
    frameind = libpointer('doublePtr',1);
    framenum = libpointer('doublePtr',0);

    if numAudioCountDown    % adapted from open loop audio countdown
        countDownPlayed = false(1,5*length(numAudioCountDown));
        %if there are speed changes in between, will have 4 counts for
        %each: 3-2-1-now & 1 for complete, moving on to next. This
        %protocol has no mid-trial speed changes (numAudioCountDown is
        %the scalar -1), so this branch and its countDownPlayed indexing
        %are unreachable here; kept for profiles that do use it.
        countDownIdx = 1;
        countDownIdxOffset = 0;
        if length(numAudioCountDown) > 1 % there is speed change in between
            speedChangeStride = numAudioCountDown(1); %set to first target
        end
        prevChangeTime = datetime('now');
    end

    loopCount = 0;          % number of completed main-loop iterations
    lastUIUpdate = tic;     % timer since belt-speed textboxes were refreshed
    handrailHigh = false;   % current handrail-force warning color state
    % Reusable per-leg marker lines: append a point per heel strike via
    % addpoints instead of creating a new plot object every stride (which
    % accumulated thousands of objects and inflated drawnow within a trial).
    % profileaxes has hold on and legend AutoUpdate off (see manualLoadProfile)
    hAnimMarkR = animatedline(ghandle.profileaxes,'LineStyle','none', ...
        'Marker','o','MarkerFaceColor',[1 0.6 0.78], ...
        'MarkerEdgeColor','r');
    hAnimMarkL = animatedline(ghandle.profileaxes,'LineStyle','none', ...
        'Marker','o','MarkerFaceColor',[0.68 0.92 1], ...
        'MarkerEdgeColor','b');

    while ~STOP     % only runs trial loop if stop button is not pressed
        while PAUSE % only runs if pause button is pressed
            pause(0.2);
            datlog.messages(end+1,:) = {'Loop paused at ',now()}; %#ok<TNOW1>
            disp(['Paused at ' char(datetime('now'))]);
            % bring treadmill to a stop and keep it there!...
            payload = getPayload(0,0,500,500,cur_incl);
            sendTreadmillPacket(payload,t);
            % do a quick save
            try
                save(savename,'datlog');
            catch ME
                disp(ME);
            end
            old_velR.Value = 1; % change the old values so that the treadmill knows to resume when the pause button is resumed
            old_velL.Value = 1;
        end
        tIter = tic;            % start per-iteration loop timer
        tSeg = tic;
        drawnow limitrate;      % throttle redraws; still flushes UI callbacks
        segGuiMs = toc(tSeg)*1000;
        tSeg = tic;
        old_stanceL = new_stanceL;
        old_stanceR = new_stanceR;

        % read frame, update necessary structures
        MyClient.GetFrame();
        framenum.Value = MyClient.GetFrameNumber().FrameNumber;
        datlog.framenumbers.data(frameind.Value,:) = [framenum.Value now()]; %#ok<TNOW1>

        % read treadmill, if enough time has elapsed since last read
        if toc(lastRead) > 0.1     % only read if enough time has elapsed
            [RBS,LBS,read_theta] = readTreadmillPacket(t);  % also read what the treadmill is doing
            lastRead = tic;
        end
        datlog.TreadmillCommands.read(frameind.Value,:) = [RBS LBS read_theta now()]; %#ok<TNOW1>
        % throttle textbox refresh to limit per-iteration graphics work
        if toc(lastUIUpdate) > 0.1     % refresh at ~10 Hz
            set(ghandle.RBeltSpeed_textbox,'String',num2str(RBS/1000));
            set(ghandle.LBeltSpeed_textbox,'String',num2str(LBS/1000));
            lastUIUpdate = tic;
        end
        frameind.Value = frameind.Value + 1;

        % capture force plate data
        Fz_R = MyClient.GetDeviceOutputValue('Right Treadmill','Fz');
        Fz_L = MyClient.GetDeviceOutputValue('Left Treadmill','Fz');
        datlog.forces.data(frameind.Value,:) = [framenum.Value now() Fz_R.Value Fz_L.Value]; %#ok<TNOW1>
        Hx = MyClient.GetDeviceOutputValue('Handrail','Fx');
        Hy = MyClient.GetDeviceOutputValue('Handrail','Fy');
        Hz = MyClient.GetDeviceOutputValue('Handrail','Fz');
        Hm = sqrt(Hx.Value^2+Hy.Value^2+Hz.Value^2);
        %if handrail force is too high, notify the experimentor; only update
        %the color on a state change to avoid dirtying the figure every loop
        handrailForceThreshold = 25; % N; above this, warn the experimenter via figure color
        if (Hm > handrailForceThreshold) && ~handrailHigh
            set(ghandle.figure1,'Color',[238 5 5]./255);
            handrailHigh = true;
        elseif (Hm <= handrailForceThreshold) && handrailHigh
            set(ghandle.figure1,'Color',[1 1 1]);
            handrailHigh = false;
        end

        %% This section was on
        if ~strcmp(Fz_R.Result,'Success') || ~strcmp(Fz_L.Result,'Success') %DMMO
            Fz_R = MyClient.GetDeviceOutputValue('Right','Fz');
            Fz_L = MyClient.GetDeviceOutputValue('Left','Fz');
            if ~strcmp(Fz_R.Result,'Success') || ~strcmp(Fz_L.Result,'Success')
                STOP = 1;  %stopUnloadVicon, the GUI can't find the forceplate values
                disp('ERROR! Adaptation GUI unable to read forceplate data, check device names and function');
                datlog.errormsgs{end+1} = 'Adaptation GUI unable to read forceplate data, check device names and function';
            end
        end
        %%
        segViconMs = toc(tSeg)*1000;    % Vicon read + interop segment
        tSeg = tic;                     % start control + stim segment

        % gait event detection
        new_stanceL = Fz_L.Value < -FzThreshold;
        new_stanceR = Fz_R.Value < -FzThreshold;
        LHS = new_stanceL && ~old_stanceL;
        RHS = new_stanceR && ~old_stanceR;
        LTO = ~new_stanceL && old_stanceL;
        RTO = ~new_stanceR && old_stanceR;

        % update gait phase state machine
        switch phase
            case 0          % double support (initial phase)
                if RTO      % advance to single stance L
                    phase = 1;
                    RstepCount = RstepCount + 1;
                    RTOTime(RstepCount) = now(); %#ok<TNOW1>
                    datlog.stepdata.RTOdata(RstepCount-1,:) = [RstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                elseif LTO  % advance to single stance R
                    phase = 2;
                    LstepCount = LstepCount + 1;
                    LTOTime(LstepCount) = now(); %#ok<TNOW1>
                    datlog.stepdata.LTOdata(LstepCount-1,:) = [LstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                end
            case 1          % single stance L
                if RHS      % advance to double stance
                    phase = 3;
                    RHSTime(RstepCount) = now(); %#ok<TNOW1>
                    datlog.stepdata.RHSdata(RstepCount-1,:) = [RstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                    % RHS marks the end of single stance L
                    % compute duration of left leg single stance phase
                    % (RHSTime/RTOTime are datenums in days; convert to ms
                    % so durSSL/estSSL stay in ms like the Arduino's copy)
                    % reject implausible durations before they corrupt the
                    % estimate (mirrors the Arduino clamp); keep the
                    % previous durSSL/estSSL on rejection so stimDelayL and
                    % the pctSS denominator stay valid
                    durSSLcand = (RHSTime(RstepCount) - ...
                        RTOTime(RstepCount)) * 86400000; % days -> ms
                    if durSSLcand >= durSSMinValidMs ...
                            && durSSLcand <= durSSMaxValidMs
                        durSSL = durSSLcand;
                        % estimate single stance duration using exponential updating factor
                        estSSL = alpha * durSSL + (1.0 - alpha) * estSSL;
                    end
                    stimDelayL = estSSL * percentSS2Stim;
                    set(ghandle.Right_step_textbox,'String',num2str(RstepCount-1));
                    % plot cursor
                    addpoints(hAnimMarkR,RstepCount-1,velR(RstepCount,1)/1000);
                    canStim = true; % single stance R is about to begin; allow its onset gate to fire

                    if LTO %In case DS is too short and a full cycle misses the phase switch
                        phase = 2;
                        LstepCount = LstepCount + 1;
                        LTOTime(LstepCount) = now(); %#ok<TNOW1>
                        datlog.stepdata.LTOdata(LstepCount-1,:) = [LstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                    end
                end
            case 2          % single stance R
                if LHS      % advance to double stance
                    phase = 4;
                    LHSTime(LstepCount) = now(); %#ok<TNOW1>
                    datlog.stepdata.LHSdata(LstepCount-1,:) = [LstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                    % LHS marks the end of single stance R
                    % compute duration of right leg single stance phase
                    % (LHSTime/LTOTime are datenums in days; convert to ms
                    % so durSSR/estSSR stay in ms like the Arduino's copy)
                    % reject implausible durations before they corrupt the
                    % estimate (mirrors the Arduino clamp); keep the
                    % previous durSSR/estSSR on rejection so stimDelayR and
                    % the pctSS denominator stay valid
                    durSSRcand = (LHSTime(LstepCount) - ...
                        LTOTime(LstepCount)) * 86400000; % days -> ms
                    if durSSRcand >= durSSMinValidMs ...
                            && durSSRcand <= durSSMaxValidMs
                        durSSR = durSSRcand;
                        % estimate single stance duration using exponential updating factor
                        estSSR = alpha * durSSR + (1.0 - alpha) * estSSR;
                    end
                    stimDelayR = estSSR * percentSS2Stim;
                    set(ghandle.Left_step_textbox,'String',num2str(LstepCount-1));
                    % plot cursor
                    addpoints(hAnimMarkL,LstepCount-1,velL(LstepCount,1)/1000);
                    canStim = true; % single stance L is about to begin; allow its onset gate to fire

                    if RTO %In case DS is too short and a full cycle misses the phase switch
                        phase = 1;
                        RstepCount = RstepCount + 1;
                        RTOTime(RstepCount) = now(); %#ok<TNOW1>
                        datlog.stepdata.RTOdata(RstepCount-1,:) = [RstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                    end
                end
            case 3          % double stance, coming from single stance L
                if LTO      % advance to single stance R
                    phase = 2;
                    LstepCount = LstepCount + 1;
                    LTOTime(LstepCount) = now(); %#ok<TNOW1>
                    datlog.stepdata.LTOdata(LstepCount-1,:) = [LstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                end
            case 4          % double stance, coming from single stance R
                if RTO      % advance to single stance L
                    phase = 1;  % advance to L single stance
                    RstepCount = RstepCount + 1;
                    RTOTime(RstepCount) = now(); %#ok<TNOW1>
                    datlog.stepdata.RTOdata(RstepCount-1,:) = [RstepCount-1 now() framenum.Value]; %#ok<TNOW1>
                end
        end

        if hreflex_present      % only do this if has the stimulator
            % Drain any device stim echoes the Arduino sent since the last
            % iteration and log the actual %-single-stance per delivered
            % pulse. This is telemetry only: drainStimEcho reads just the
            % bytes already waiting in the OS buffer (never blocks) and the
            % whole block is wrapped so a serial hiccup can never abort the
            % trial. A dropped echo is a non-event. With old firmware that
            % does not echo, NumBytesAvailable stays 0 and this is a no-op.
            try
                [echoBuf,echoRecs] = drainStimEcho(portArduino,echoBuf);
                for er = 1:size(echoRecs,1)
                    legNum      = echoRecs(er,1);
                    ardStep     = echoRecs(er,2);
                    stimMs      = echoRecs(er,3);
                    toRefMs     = echoRecs(er,4);
                    estSSms     = echoRecs(er,5);
                    isDelivered = echoRecs(er,6);
                    dtStimMs = stimMs - toRefMs; % elapsed into single stance
                    if legNum == 1     % left record: single stance L
                        matStep = RstepCount;
                        durSSms = durSSL; % most recent measured (ms)
                    else               % right record: single stance R
                        matStep = LstepCount;
                        durSSms = durSSR;
                    end
                    pctSS = 100 * dtStimMs / durSSms;
                    matTimeSerial = now(); %#ok<TNOW1>
                    stimRow = [legNum ardStep matStep stimMs toRefMs ...
                        estSSms dtStimMs durSSms pctSS matTimeSerial];

                    % ardStep regression sentinel (applies to both
                    % delivered and dropped records: both reflect the
                    % same Arduino-side counter)
                    if legNum == 1
                        if ardStep < prevArdStepL && ~ardStepWarnedL
                            msg = sprintf(['Left ardStep decreased ' ...
                                '(%d -> %d): Arduino step counter may ' ...
                                'have reset mid-trial'], ...
                                prevArdStepL,ardStep);
                            datlog.errormsgs{end+1} = msg;
                            warning(['NirsHreflexArduinoOpenLoopWith' ...
                                'Audio:ArdStepReset'],'%s',msg);
                            ardStepWarnedL = true;
                        end
                        prevArdStepL = ardStep;
                    else
                        if ardStep < prevArdStepR && ~ardStepWarnedR
                            msg = sprintf(['Right ardStep decreased ' ...
                                '(%d -> %d): Arduino step counter may ' ...
                                'have reset mid-trial'], ...
                                prevArdStepR,ardStep);
                            datlog.errormsgs{end+1} = msg;
                            warning(['NirsHreflexArduinoOpenLoopWith' ...
                                'Audio:ArdStepReset'],'%s',msg);
                            ardStepWarnedR = true;
                        end
                        prevArdStepR = ardStep;
                    end

                    if isDelivered
                        datlog.stim.deviceEcho.data(end+1,:) = stimRow;
                    else
                        datlog.stim.deviceDrop.data(end+1,:) = stimRow;
                    end
                    reportStimPctSS(legNum,ardStep,pctSS,dtStimMs, ...
                        isDelivered);
                end
            catch ME
                datlog.errormsgs{end+1} = ['Stim echo drain error: ' ...
                    ME.message];
            end

            if isnan(stimInterval)
                shouldStimR = logical(stimR(RstepCount));
                shouldStimL = logical(stimL(LstepCount));
            else
                shouldStimR = mod(RstepCount,stimInterval) == 4;
                shouldStimL = mod(LstepCount,stimInterval) == 4;
            end

            % Send the gate during the double support phase immediately
            % preceding single-stance onset (phase 3 for R, 4 for L): the
            % Arduino only latches shouldStimL/R and waits for its own
            % 50%-single-stance trigger, so arriving a full double-support
            % period early is safe and strictly widens the margin before
            % that trigger versus sending at onset. The || phase == 2/1
            % fallback covers the rare double-support-skip edge (embedded
            % LTO/RTO below), where canStim was set in the same iteration
            % phase advanced straight to single stance; RstepCount/
            % LstepCount are unchanged between the double-support and
            % single-stance phases (they only advance on the contralateral
            % toe-off), so shouldStimR/L select the same strides either way.
            if (shouldStimR && (phase == 3 || phase == 2) && canStim)
                if isCalibration    % play sound
                    play(CalibAudioR);
                end

                try         % send command to Arduino to stimulate right
                    % value frozen with the firmware; must stay one byte
                    % ('uint8') -- see the cmdArduino* comment above.
                    write(portArduino,cmdArduinoStimR,'uint8');
                catch ME
                    warning(ME.identifier,['Failed to send right leg ' ...
                        'stimulation command to Arduino: %s'],ME.message);
                end
                canStim = false;
                % pending; resolved to a lead time once single-stance R
                % onset (LTO) is observed below
                gateSentTimeR = now(); %#ok<TNOW1>
                datlog.stim.R(end+1,:) = ...
                    [RstepCount stimDelayR gateSentTimeR];
            end

            if (shouldStimL && (phase == 4 || phase == 1) && canStim)
                if isCalibration    % play sound
                    play(CalibAudioL);
                end

                try         % send command to Arduino to stimulate left
                    write(portArduino,cmdArduinoStimL,'uint8');
                catch ME
                    warning(ME.identifier,['Failed to send left leg ' ...
                        'stimulation command to Arduino: %s'],ME.message);
                end

                canStim = false;    % prevent immediate re-stimulation
                % pending; resolved to a lead time once single-stance L
                % onset (RTO) is observed below
                gateSentTimeL = now(); %#ok<TNOW1>
                datlog.stim.L(end+1,:) = ...
                    [LstepCount stimDelayL gateSentTimeL];
            end

            % Resolve any pending gate send into a lead-time diagnostic once
            % its single-stance onset event has actually been observed
            % (LTOTime/RTOTime were just updated by the state machine above
            % this block, in the same loop iteration as the phase change).
            if ~isnan(gateSentTimeR) && phase == 2
                datlog.diagnostics.gateLeadMsR(end+1) = ...
                    (LTOTime(LstepCount) - gateSentTimeR) * 86400000;
                gateSentTimeR = NaN;
            end
            if ~isnan(gateSentTimeL) && phase == 1
                datlog.diagnostics.gateLeadMsL(end+1) = ...
                    (RTOTime(RstepCount) - gateSentTimeL) * 86400000;
                gateSentTimeL = NaN;
            end
        end

        %check if should log NIRS events
        if nextNirsEventIdx <= length(nirsEventSteps)
            if (LstepCount == nirsEventSteps(nextNirsEventIdx) || RstepCount == nirsEventSteps(nextNirsEventIdx)) && need2LogEvent
                %log it, move on to the next target and avoid coming here multiple
                %times.
                nirsEventString = nirsEventNames{nextNirsEventIdx};
                isStartEvent = ismember(nirsEventString, tmStartEventNames);
                if isStartEvent && suppressFirstStartCue
                    % bout 1's "walk" cue was already announced by the
                    % pre-loop block above; log the NIRS marker without
                    % playing the cue again.
                    audioKey = [nirsEventString '_noaudio'];
                    suppressFirstStartCue = false;
                else
                    audioKey = nirsEventString;
                end
                datlog = nirsEvent(audioKey, nirsEventString(1), [nirsEventString num2str(nextRestIdx-1+trainIdx)], instructions, datlog, Oxysoft, oxysoft_present);
                % wait till 2 steps later to log event again to avoid same
                % event logged multiple times.
                need2LogEvent = false;
                if isStartEvent && strcmp(audioKey, nirsEventString) %starting TM again and the cue actually played, give it time.
                    walkCuePlayer = instructions('walk');
                    pause(walkCuePlayer.TotalSamples / walkCuePlayer.SampleRate ...
                        + startCueSettleSec); %let the cue finish, plus a settle margin before belts move
                end
            elseif LstepCount >= nirsEventSteps(nextNirsEventIdx)+1 && RstepCount >= nirsEventSteps(nextNirsEventIdx)+1
                %now have past the most recent change by at least 1 steps both side, reset the flag
                need2LogEvent = true;
                nextNirsEventIdx = nextNirsEventIdx + 1;
            end
        end

        if numAudioCountDown %Adapted from open loop audio countdown
            if length(numAudioCountDown) > 1 && speedChangeStride ~= -1 %there is speed change in the middle and there is more change incoming (if -1 means next is TM end)
                if (LstepCount == speedChangeStride-3 || RstepCount == speedChangeStride-3) && ~countDownPlayed(1+countDownIdxOffset)
                    fprintf(['Change at ' num2str(speedChangeStride) '-3 Stride . Date Time: ' char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS') '\n']);
                    fprintf('Current step count L: %d, R:%d, countDownIdx: %d, idx offset: %d\n',LstepCount,RstepCount,countDownIdx, countDownIdxOffset)

                    %log in NIRS that audio count down is happening. FIXME
                    datlog = nirsEvent('TMStopAudioCountDown', 'D', ['TMStopAudioCountDown_Train' num2str(nextRestIdx-1+trainIdx)], instructions, datlog, Oxysoft, oxysoft_present);

                    play(AudioTMChange3);
                    countDownPlayed(countDownIdx) = true; %This should only be run once
                    countDownIdx = countDownIdx + 1;
                elseif (LstepCount == speedChangeStride-1 || RstepCount == speedChangeStride-1) && ~countDownPlayed(2+countDownIdxOffset)
                    fprintf(['Change-2 Stride . Date Time: ' char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS') '\n']);
                    fprintf('Current step count L: %d, R:%d, countDownIdx: %d, idx offset: %d\n',LstepCount,RstepCount,countDownIdx, countDownIdxOffset)
                    play(AudioCount2);
                    countDownPlayed(countDownIdx) = true; %This should only be run once
                    countDownIdx = countDownIdx + 1;
                elseif (LstepCount == speedChangeStride || RstepCount == speedChangeStride) && ~countDownPlayed(3+countDownIdxOffset)
                    fprintf(['Change at ' num2str(speedChangeStride) ' Last Stride . Date Time: ' char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS') '\n']);
                    fprintf('Current step count L: %d, R:%d, countDownIdx: %d, idx offset: %d\n',LstepCount,RstepCount,countDownIdx, countDownIdxOffset)
                    disp(countDownPlayed)
                    play(AudioCount1)
                    countDownPlayed(countDownIdx) = true; %This should only be run once
                    countDownIdx = countDownIdx + 1;
                elseif (LstepCount == speedChangeStride+1 || RstepCount == speedChangeStride+1) && ~countDownPlayed(4+countDownIdxOffset)
                    fprintf(['Change Stride +1. Date Time: ' char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS') '\n']);
                    play(AudioNow)
                    countDownPlayed(countDownIdx) = true; %This should only be run once
                    countDownIdx = countDownIdx + 1;
                elseif (LstepCount >= speedChangeStride+2 && RstepCount >= speedChangeStride+2) && ~countDownPlayed(5+countDownIdxOffset) && seconds(datetime('now') - prevChangeTime) > 3 %don't try this again untill 3s has passed
                    %both legs are above speedChangeStride+1, finished the
                    %change, move on to next target
                    countDownIdxOffset = countDownIdxOffset + 5; %finished one change, don't do this again
                    speedChangeStride = numAudioCountDown(countDownIdxOffset/5+1); %move on to the next change target
                    fprintf('Done change. Next target: %d\n', speedChangeStride)
                    fprintf('Current step count L: %d, R:%d, countDownIdx: %d, idx offset: %d\n',LstepCount,RstepCount,countDownIdx, countDownIdxOffset)
                    countDownPlayed(countDownIdx) = true; %This should only be run once
                    countDownIdx = countDownIdx + 1;
                    prevChangeTime = datetime('now');
                end
            end %end conditional block for when there is step change in the middle
        end

        if LstepCount >= N || RstepCount >= N%if taken enough steps, stop
            break
            % send treadmill command only if speed changes
        elseif (velR(RstepCount,1) ~= old_velR.Value) || (velL(LstepCount,1) ~= old_velL.Value)% && LstepCount<N && RstepCount<N
            % A belt resuming from a genuine stop (old_velR/L.Value == 0,
            % e.g. right after a mid-trial rest break) is the same both-
            % feet-planted condition as the pre-loop first command above,
            % so use accInitial there too instead of the normal acc.
            if old_velR.Value == 0
                accSendR = accInitial;
            else
                accSendR = acc;
            end
            if old_velL.Value == 0
                accSendL = accInitial;
            else
                accSendL = acc;
            end
            payload = getPayload(velR(RstepCount,1),velL(LstepCount,1), ...
                accSendR,accSendL,cur_incl);
            sendTreadmillPacket(payload,t);
            datlog.TreadmillCommands.sent(frameind.Value,:) = [velR(RstepCount,1) velL(LstepCount,1) cur_incl now()]; %#ok<TNOW1> % record the command
            disp(['Packet sent, Lspeed = ' num2str(velL(LstepCount,1)) ', Rspeed = ' num2str(velR(RstepCount,1))]);
        else
            %simply record what the treadmill should be doing
            %datlog.TreadmillCommands.sent(frameind.Value,:) = [velR(RstepCount),velL(LstepCount),cur_incl,now];%record the command
            %Pablo commented out on 26/2/2018 because it is unnecessary and takes time to save later.
        end

        old_velR.Value = velR(RstepCount,1);
        old_velL.Value = velL(LstepCount,1);

        if need2LogEvent && nextRestIdx <= length(restSteps) && (LstepCount == restSteps(nextRestIdx) || RstepCount == restSteps(nextRestIdx))  %time for a rest
            need2LogEvent = false;
            %for all rest except for the 1st (starting with a rest TM is not
            %moving)

            % make sure TM is at zero and hold it there.
            [payload] = getPayload(0,0,acc,acc,cur_incl);
            sendTreadmillPacket(payload,t);
            pause(1.5); % give the belts a moment to settle at zero before
            % the stop/count-forward cues play below.
            % this function plays the 'stop' audio, sends event to NIRS,
            % and logs it in datlog
            datlog = nirsEvent('stop','R',['Rest' num2str(nextRestIdx+trainIdx)],instructions,datlog,Oxysoft,oxysoft_present);
            pause(stopCueSec); % block until 'stop' finishes playing so
            % 'silentlyCountForward' starts right after without overlap
            play(instructions('silentlyCountForward'));
            datlog.audioCues.start(end+1) = now(); %#ok<TNOW1>
            datlog.audioCues.audio_instruction_message{end+1} = ...
                ['Rest' num2str(nextRestIdx+trainIdx) '_CountForward'];
            %instead of a fixed pause, run a WHILE loop here so that the program wouldn't hang and would
            % respond to STOP in the rest break.
            restTic = tic;
            restDone = false;
            while ~restDone && ~STOP
                t_diff = toc(restTic); % elapsed seconds since rest began
                if t_diff >= restDuration-0.5 %enough time to rest has passed. moving on, should never be in the second or loop situation
                    restDone = true;
                else
                    pause(0.8); % pause for a bit so we are not doing the while loop nonstop.
                    [~,~,~] = readTreadmillPacket(t);   % this is to maintain communication with the treamdill to avoid lag after the break.
                end
            end
            if STOP     % anytime if STOP is pressed, quit the while loop
                break;  % break the while loop
            end
            %done, advance step count to the next walking event.(notice that
            %assumes there is always an event immediately after the rest,
            %(e.g., rest is at step 200, there will be an event at step 250,
            %and rest duration is coded as 50 steps).
            if nextNirsEventIdx <= length(nirsEventSteps) %assign stepCont to next event, only if there is still more event coming.
                LstepCount = nirsEventSteps(nextNirsEventIdx);
                RstepCount = nirsEventSteps(nextNirsEventIdx); %it appears that we always take coded stride - 1 steps (but that's how it is in open loop controller too bc stepcount started at 1 intead of 0)
            else %otherwise assume rest is the last thing the script will do.
                STOP = true;    % manually set stop to the experiments
            end
            need2LogEvent = true;
            nextRestIdx = nextRestIdx + 1;
        end

        % record per-iteration loop-timing diagnostics (additive)
        loopCount = loopCount + 1;
        datlog.diagnostics.loopSegMs(loopCount,:) = ...
            [toc(tIter)*1000, segGuiMs, segViconMs, toc(tSeg)*1000];
    end     % while, when STOP button is pressed

    % trim unused preallocated diagnostic rows
    datlog.diagnostics.loopSegMs(loopCount+1:end,:) = [];

    if STOP
        datlog.messages(end+1,:) = {'Stop button pressed at: [see next cell] ,stopping... ',now()}; %#ok<TNOW1>
        disp(['Stop button pressed, stopping... ' char(datetime('now'))]);
        set(ghandle.Status_textbox,'String','Stopping...');
        set(ghandle.Status_textbox,'BackgroundColor','red');
    end

    % log the final event marking trial end, without audio telling participant
    % to relax. This log could happen 1-2 seconds before TM fully stops which
    % is ok bc stopping usually could be perturbing and this probably marks a
    % better steady state ending.
    % audio cue here would be too early, so just log the event without saying anything yet (see Alt Option below).
    datlog = nirsEvent('relax_noaudio','O','Trial_End',instructions,datlog,Oxysoft,oxysoft_present);
catch ME
    datlog.errormsgs{end+1} = 'Error occurred during the control loop';
    datlog.errormsgs{end+1} = ME;
    disp('Error occurred during the control loop, see datlog for details...');
end
%% Closing Routine
% end communications
try
    save(savename,'datlog');
    delete(syncname);   % delete sync file in prep for next trial
catch ME
    disp(ME);
end

if hreflex_present      % if hreflex, stop the Arduino state machine and close communication
    % Sent here (rather than only on the no-error path inside the main
    % try) so the Arduino's state machine is stopped even if the control
    % loop above threw an error. handleStimulationTimeout() on the Arduino
    % runs regardless of the state machine, so any in-flight pulse still
    % clears safely either way.
    try
        fprintf('Sending command to stop the Arduino state machine...\n');
        write(portArduino,cmdArduinoStop,'uint8'); % stop state machine
        fprintf('Stop state machine command sent successfully.\n');
    catch ME
        warning(ME.identifier,['Failed to send stop state machine ' ...
            'command to Arduino: %s'],ME.message);
    end

    datlog.messages(end+1,:) = {'Closing Arduino port...',now()}; %#ok<TNOW1>
    fprintf('Closing Arduino serial port...\n');
    try
        flush(portArduino);     % flush remaining data in the buffer
        delete(portArduino);    % close and clear the serial port object
        fprintf('Arduino serial port closed successfully.\n');
    catch ME
        warning(ME.identifier,'Failed to close Arduino port properly: %s',ME.message);
    end
end

try % stopping the treadmill
    % see if the treadmill is supposed to stop at the end of the profile
    if get(ghandle.StoptreadmillEND_checkbox,'Value') == 1 && ~STOP
        set(ghandle.Status_textbox,'String','Stopping...');
        set(ghandle.Status_textbox,'BackgroundColor','red');
        set(ghandle.figure1,'Color',[1 1 1]);
        pause(0.5); % Pablo I. wrote "Do we need this?"
        fprintf('Trying to stop treadmill (TM1) at %s\n',char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
        smoothStop(t);
        if numAudioCountDown % announce the trial has stopped; no countdown
            play(instructions('stop'));
            pause(stopCueSec); % avoid overlapping the two cues
            play(instructions('silentlyCountForward'));
        end
        % see if the treadmill should be stopped when the STOP button is pressed
    elseif get(ghandle.StoptreadmillSTOP_checkbox,'Value') == 1 && STOP == 1
        set(ghandle.Status_textbox,'String','Stopping');
        set(ghandle.Status_textbox,'BackgroundColor','red');
        pause(0.3);
        fprintf('Trying to stop treadmill (TM2) at %s\n',char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
        smoothStop(t);
    end

    %Say  "Relax" without sending another event to NIRS (last arg always false).
    %Alt Option: this could be a good time to say "Relax" and the time
    %point would be exactly when TM stopped, but logging timing is better right after the last stride without audio and before the closing routine above.
    %the activity during the closing routine shouldn't really be analyzed.
    %     datlog = nirsEvent('relax','O','Trial_End_TMStop', instructions, datlog, Oxysoft, false);

    % check if treadmill stopped, if not, try again:
    pause(1);
    fprintf('Trying to stop treadmill (TM3) at %s\n',char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
    [cur_speedR,cur_speedL,cur_incl] = readTreadmillPacket(t);
    stopped = (cur_speedR == 0) && (cur_speedL == 0);
    maxStopAttempts = 5;
    counter = 0;
    while ~stopped && counter < maxStopAttempts   % try a few times to stop the treadmill smoothly
        disp('Treadmill did not stop as requested. Retrying...');
        fprintf('Attempt %d to stop treadmill at %s\n',counter,char(datetime('now'),'yyyy-MM-dd HH:mm:ss:SSS'));
        pause(1);   % give time to smoothStop to execute everything
        [cur_speedR,cur_speedL,cur_incl] = readTreadmillPacket(t);
        stopped = (cur_speedR == 0) && (cur_speedL == 0);
        counter = counter + 1;
    end
    if counter >= maxStopAttempts
        disp('Could not stop treadmill after maximum attempts');
    end
catch ME
    datlog.errormsgs{end+1} = 'Error stopping the treadmill';
    datlog.errormsgs{end+1} = ME;
end

disp('Closing communications...');
try
    closeNexusIface(MyClient);
    closeTreadmillComm(t);
catch ME
    datlog.errormsgs{end+1} = ['Error ocurred when closing communications with Nexus & Treadmill at ' char(datetime('now'))];
    datlog.errormsgs{end+1} = ME;
    disp(['Error ocurred when closing communications with Nexus & Treadmill, see datlog for details ' char(datetime('now'))]);
    disp(ME);
end

%% Convert and Save Timing Data (Vectorized)
disp('Converting time in datlog...');
% convert time data into clock format then re-save
datlog.buildtime = char(buildTime,'dd-MMM-yyyy HH:mm:ss');

% NOTE: the relative-time columns below (col 3/4/5 in each block) are
% consumed downstream by labTools' SyncDatalog for force-signal
% alignment, so they must stay value-identical to today's output, not
% just type-identical. A datetime-subtraction replacement
% (seconds(datetime(a,'ConvertFrom','datenum')-datetime(b,...))) was
% verified empirically (200k-sample test) to differ from
% etime(datevec(a),datevec(b)) by up to ~5e-5 s -- small, but not the
% bit-identical match this field requires, so etime/datevec (neither of
% which triggers a Code Analyzer warning on its own) is kept here
% on purpose; only the outer etime call needs the suppression.
% convert frame times
temp = find(isnan(datlog.framenumbers.data(:,1)),1,'first');
datlog.framenumbers.data(temp:end,:) = [];

if isempty(temp) || temp <= 1
    % No frames were ever logged this trial (e.g., the trial aborted
    % before the main loop ran -- see datlog.errormsgs for the cause,
    % such as a failed Nexus/treadmill connection). The columns below
    % all key off datlog.framenumbers.data(1,2), which does not exist
    % in this case, so skip relative-time conversion and save the raw
    % (unconverted) datlog instead of crashing here.
    disp('No frames logged this trial; skipping relative-time conversion.');
else
    for z = 1:temp-1
        datlog.framenumbers.data(z,3) = etime(datevec(datlog.framenumbers.data(z,2)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end
    % convert force times
    datlog.forces.data(1,:) = [];
    temp = find(isnan(datlog.forces.data(:,1)),1,'first');
    datlog.forces.data(temp:end,:) = [];
    for z = 1:temp-1
        datlog.forces.data(z,5) = etime(datevec(datlog.forces.data(z,2)),datevec(datlog.forces.data(1,2))); %#ok<DETIM>
    end
    % convert RHS times
    datlog.stepdata.RHSdata(temp:end,:) = [];
    temp = size(datlog.stepdata.RHSdata,1) + 1;
    for z = 1:temp-1
        datlog.stepdata.RHSdata(z,4) = etime(datevec(datlog.stepdata.RHSdata(z,2)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end
    % convert LHS times
    for z = 1:temp-1
        datlog.stepdata.LHSdata(z,4) = etime(datevec(datlog.stepdata.LHSdata(z,2)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end
    % convert RTO times
    for z = 1:temp-1
        datlog.stepdata.RTOdata(z,4) = etime(datevec(datlog.stepdata.RTOdata(z,2)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end
    % convert LTO times
    for z = 1:temp-1
        datlog.stepdata.LTOdata(z,4) = etime(datevec(datlog.stepdata.LTOdata(z,2)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end

    % convert command times
    temp = all(isnan(datlog.TreadmillCommands.read(:,1:4)),2);
    datlog.TreadmillCommands.read = datlog.TreadmillCommands.read(~temp,:);
    for z = 1:size(datlog.TreadmillCommands.read,1) % compute relative time and fill in the last column
        datlog.TreadmillCommands.read(z,5) = etime(datevec(datlog.TreadmillCommands.read(z,4)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end

    try
        firstTMTime = datlog.TreadmillCommands.read(1,4);
        lastTMTime = datlog.TreadmillCommands.read(end,4);
        fprintf(['\n\nTreadmill First Packet Read Time. Universal Time: ' num2str(firstTMTime) '. Date Time: ' char(datetime(firstTMTime,'ConvertFrom','datenum'),'yyyy-MM-dd HH:mm:ss:SSS') '\n']);
        fprintf(['Treadmill Last Packet Read Time. Universal Time: ' num2str(lastTMTime) '. Date Time: ' char(datetime(lastTMTime,'ConvertFrom','datenum'),'yyyy-MM-dd HH:mm:ss:SSS') '\n\n']);
    catch
        fprintf('Unable to get TM packets start and end time');
    end

    % convert audio times
    datlog.audioCues.start = datlog.audioCues.start';
    datlog.audioCues.audio_instruction_message = datlog.audioCues.audio_instruction_message';
    temp = isnan(datlog.audioCues.start);
    disp('\nConverting datalog, current starts \n');
    disp(datlog.audioCues.start);
    datlog.audioCues.start = datlog.audioCues.start(~temp);
    datlog.audioCues.startInRelativeTime = (datlog.audioCues.start - datlog.framenumbers.data(1,2)) * 86400;
    datlog.audioCues.startInDateTime = datetime(datlog.audioCues.start,'ConvertFrom','datenum');

    temp = all(isnan(datlog.TreadmillCommands.sent(:,1:4)),2);
    datlog.TreadmillCommands.sent = datlog.TreadmillCommands.sent(~temp,:);
    for z = 1:size(datlog.TreadmillCommands.sent,1)
        datlog.TreadmillCommands.sent(z,5) = etime(datevec(datlog.TreadmillCommands.sent(z,4)),datevec(datlog.framenumbers.data(1,2))); %#ok<DETIM>
    end
end

disp('Saving datlog...');
try
    save(savename,'datlog');
catch ME
    disp(ME);
end

end

%% Local Functions

function [bufOut,recs] = drainStimEcho(port,bufIn)
%DRAINSTIMECHO Non-blocking read of Arduino stim-echo records.
%
%   Reads only the bytes already waiting in the serial input buffer (it
%   never blocks), appends them to any partial line carried over from the
%   previous call, and delegates record extraction to PARSESTIMECHO. With
%   firmware that does not echo, NumBytesAvailable stays 0 and this returns
%   immediately with no records, so the controller degrades cleanly.
%
% Inputs:
%   port - open serialport object connected to the Arduino
%   bufIn - partial line text left over from the previous call
%
% Outputs:
%   bufOut - partial line text to carry into the next call
%   recs - Px6 numeric array, one row per parsed record:
%          [leg(1=L,2=R), ardStep, stimMs, toRefMs, estSSms, isDelivered]
%
% Toolbox Dependencies: None
%
% See also PARSESTIMECHO, NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO.

nAvail = port.NumBytesAvailable;
if nAvail == 0      % nothing waiting (also the no-echo-firmware no-op path)
    bufOut = bufIn;
    recs = zeros(0,6);
    return;
end
[bufOut,recs] = parseStimEcho([bufIn char(read(port,nAvail,'char'))]);

end

function reportStimPctSS(legNum,ardStep,pctSS,dtStimMs,isDelivered)
%REPORTSTIMPCTSS Print the device-echoed pulse or dropped-gate outcome.
%
%   Surfaces, on the console, where the Arduino actually delivered a pulse
%   relative to single stance so the experimenter can spot gross timing
%   errors online. Values outside the target window are flagged;
%   physically impossible values (<0 or >100) signal an echo/event
%   matching problem rather than a real out-of-tolerance stim. A dropped
%   gate (the firmware's lateness or gate-expiry guard) is reported by
%   elapsed time, not %SS: the gate-expiry case can carry a stale
%   contralateral toe-off reference (the single stance never arrived),
%   which would make pctSS meaninglessly large rather than informative.
%
% Inputs:
%   legNum - 1 = left, 2 = right
%   ardStep - Arduino-side step counter for the record
%   pctSS - actual stim point as a percentage of single stance (ignored
%          for a dropped gate; see dtStimMs)
%   dtStimMs - elapsed ms from the contralateral toe-off reference to the
%          pulse (or, for a dropped gate, to when the drop was detected)
%   isDelivered - true if the Arduino fired the pulse, false if the
%          firmware dropped the gate instead
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO.

pctTargetSS    = 50; % target stim point (% of single stance)
pctToleranceSS = 5;  % acceptance half-window (%) for the online check
if legNum == 1
    legStr = 'L';
else
    legStr = 'R';
end

if ~isDelivered
    fprintf(['Stim %s step %d: gate DROPPED by firmware (%.0f ms ' ...
        'since toe-off ref)\n'],legStr,ardStep,dtStimMs);
elseif pctSS < 0 || pctSS > 100
    fprintf(['Stim %s step %d: %.1f%% SS (out of range; check echo/' ...
        'event matching)\n'],legStr,ardStep,pctSS);
elseif abs(pctSS - pctTargetSS) > pctToleranceSS
    fprintf('Stim %s step %d: %.1f%% SS (OUTSIDE %d+/-%d%%)\n', ...
        legStr,ardStep,pctSS,pctTargetSS,pctToleranceSS);
else
    fprintf('Stim %s step %d: %.1f%% SS\n',legStr,ardStep,pctSS);
end

end
