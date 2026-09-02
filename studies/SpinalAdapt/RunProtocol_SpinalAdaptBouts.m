%RUNPROTOCOL_SPINALADAPTBOUTS Automate the SpinalAdapt experimental session.
%
%   TEMPLATE — Updated with new SpinalAdapt protocol structure:
%   13 conditions (2 familiarization, 6 control bouts trials, 5 split
%   bouts trials). Verify all conditions against the final approved
%   protocol before data collection.
%   See History-PilotStudy2/ for the Pilot Study 2 original.
%
%   Guides the experimenter through profile generation, pre- and post-
%   session H-reflex calibration trials, all conditions in sequence, and
%   post-session data transfer to the server. Edit the EXPERIMENTER
%   section below before each session run.
%
% Toolbox Dependencies:
%   None (external: AdaptationGUI, Vicon Nexus, labTools dataMotion)
%
% See also GENERATEPROFILES_SPINALADAPTBOUTS, RUNWALKINGCALIBRATIONS,
%   TRANSFERDATA_SPINALADAPTBOUTS.

%% EXPERIMENTER: Enter Subject-Specific Parameters Before Each Session
speedProportion = 0.5;  % slow / fast speed ratio

% for stroke participants use SASS01V01 (Sub##V## format)
subjectID = 'SAYA01';   % SAYA##V## for young, SASS##V## for stroke, SAMC

fastLeg = 'R'; % 'R' or 'L'; for healthy: dominant leg; for stroke:
% non-paretic (session 1) or paretic (session 2).

% Compute fastSpeed from the N-Minute Walk Test (NMWT): opens a dialog
% to collect raw walk test measurements and returns the participant's
% comfortable overground walking speed (m/s), used as the fast belt speed.
fastSpeed = utils.extractSpeedsNMWT();
slowSpeed = fastSpeed * speedProportion;

% date threshold for copying recent files in datlogs
threshTime = datetime('now', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

%% Generate Speed Profiles From Experimenter Input
dirProfile = fullfile( ...
    'C:\Users\Public\Documents\MATLAB\ExperimentalGUI', ...
    'profiles', 'SpinalAdaptNirsStudy', subjectID);
answer = 'Yes';                     % default to 'yes', don't check it
if contains(subjectID, 'V01')
    answer = questdlg(['Visit 1: Fast leg should be NON-paretic / ' ...
        'Dominant leg, which is ' fastLeg ' Is that correct?']);
elseif contains(subjectID, 'V02')
    answer = questdlg(['Visit 2: Fast leg should be paretic / ' ...
        'NON-Dominant leg, which is ' fastLeg ' Is that correct?']);
end
if ~strcmp(answer, 'Yes')
    return;         % abort: fix the fast leg assignment first
end

opts.Interpreter = 'tex';
opts.Default     = 'No, I generated them already';
profileToGen = questdlg(['Regenerate profile? Confirm speed and ' ...
    'subject ID are correct in RunProtocol_SpinalAdaptBouts.m '], ...
    'RegenProfile', 'Yes', 'No, I generated them already', opts);
switch profileToGen
    case 'Yes'
        answer = questdlg(['Just to double check: now create profile ' ...
            'where the fast leg is ' fastLeg ' Is that correct?']);
        if ~strcmp(answer, 'Yes')
            return;     % abort: fix fast leg assignment
        end
        generateProfiles_SpinalAdaptBouts(slowSpeed, fastSpeed, ...
            dirProfile, fastLeg);
    case 'No, I generated them already'
        disp('Profile generated already. Continue with the experiments');
    otherwise
        disp('No response given, quit the script now.');
        return;
end

%% Set Up the GUI and Define Session Constants
[audio_data, audio_fs] = audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data, audio_fs);

handles = guidata(AdaptationGUI);

% NOTE: these variables are needed as controller function input arguments
global profilename
global numAudioCountDown
global isCalibration

maxCon              = 13;   % maximum number of conditions
pauseBetweenTrials  = 55;   % s; ~90 s wall clock including the ~35 s
                             % Vicon stop/start delay
ctrlSlotNirsHreflex = 14;   % GUI slot: NirsHreflexArduinoOpenLoopWithAudio
ctrlSlotOgWalkTest  = 8;    % GUI slot: HreflexOGWithAudio, no stim
pauseTransferSec    = 60;   % s; allows Vicon to stop and save last trial

%% Complete Overground 6-Minute Walk Test
% One-time trial at the very start of the session; not part of the
% numbered condition switch below since it isn't one of the 13 main
% protocol conditions. Self-paced (NaN profile) — answer 'No' to the
% audio feedback prompt below so the participant walks at their own pace.
handles.popupmenu2.set('Value', ctrlSlotOgWalkTest);
profilename = fullfile(dirProfile, 'SixMinuteWalk.mat');
manualLoadProfile([], [], handles, profilename);
answer = questdlg(['Confirm controller is Overground audio speed ' ...
    'feedback and profile is SixMinuteWalk. When prompted for audio ' ...
    'feedback, answer No (self-paced 6-minute walk test).']);
if ~strcmp(answer, 'Yes')
    return;
end
AdaptationGUI('Execute_button_Callback', ...
    handles.Execute_button, [], handles);
% manually stop in the GUI once six minutes of walking have elapsed

%% Complete Pre-Session H-Reflex Walking Calibration Trials
isCalibration = true;   % run at least once (slow & fast speeds)
while isCalibration     % repeat until experimenter selects 'No'
    isCalibration = runWalkingCalibrations(handles, dirProfile);
end

%% Run the Main SpinalAdapt Protocol Conditions
% NOTE: audio cues for "TM will start / stop now" are approximate and
% may be difficult to improve given the GUI callback latency.
isFirstCon = true;      % is this the first condition in the session?
currCon    = 0;         % current condition index; loop runs while < maxCon
while currCon < maxCon
    if ~isFirstCon      % after first condition, ask whether to auto-advance
        nextConButton = questdlg(['Would you like to automatically ' ...
            'continue with the next condition?']);
        if strcmp(nextConButton, 'Yes')
            currCon = currCon + 1;
        elseif strcmp(nextConButton, 'No')
            currCon = inputdlg(['Which condition do you want to start' ...
                ' from (1 = Familiarization slow, 2 = Familiarization ' ...
                'fast, 3 = 1st control trial, 4 = 1st split trial, ' ...
                'enter the number from the 1st col on the data sheet)?']);
            disp(['Starting from condition #' currCon{1}]);
            currCon = str2double(currCon{1});
        else
            return;     % cancel: end the experiment
        end
    else
        isFirstCon = false;
        currCon = inputdlg(['Which condition do you want to start' ...
            ' from (1 = Familiarization slow, 2 = Familiarization ' ...
            'fast, 3 = 1st control trial, 4 = 1st split trial, ' ...
            'enter the number from the 1st col on the data sheet)?']);
        disp(['Starting from condition #' currCon{1}]);
        currCon = str2double(currCon{1});
    end

    switch currCon
        case 1          % Familiarization Slow (Tied)
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'FamBoutsSlow.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio countdown and profile is ' ...
                'FamBoutsSlow']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            % no fixed break here — proceed immediately in GUI
        case 2          % Familiarization Fast (Tied)
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'FamBoutsFast.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio countdown and profile is ' ...
                'FamBoutsFast']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            % no fixed break here — proceed immediately in GUI
        case {3, 9, 10, 11, 12, 13} % Control Bouts (Tied)
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'CtrlBouts.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is CtrlBouts']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for ~90 s wall clock
            play(AudioTimeUp);
        case {4, 5, 6, 7, 8}        % Split Bouts Trials 1-8
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'SplitBouts.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is SplitBouts']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for ~90 s wall clock
            play(AudioTimeUp);
    end
end

%% Complete End-of-Session H-Reflex Walking Calibration Trials
isCalibration = runWalkingCalibrations(handles, dirProfile);

%% Transfer Session Data to Server
% pauseTransferSec allows Vicon Nexus to stop and save the last C3D file
pause(pauseTransferSec);
tic;
transferData_SpinalAdaptBouts(subjectID, threshTime);
toc;

%% Run Reconstruct and Label Pipeline and Fill Marker Gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLY RUN THIS BLOCK ON THE LAB PC1 IF THERE IS SUFFICIENT TIME BEFORE
% THE NEXT EXPERIMENTER NEEDS THE LAB SPACE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TODO: update path below for participants with stroke (two visits)
tic;
dirSrvrData = fullfile('W:\SpinalAdaptStudy\Data', subjectID, 'Vicon');
dataMotion.processAndFillMarkerGapsSession(dirSrvrData);
toc;
