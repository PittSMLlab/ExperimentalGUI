%RUNPROTOCOL_SPINALADAPTBOUTS Run the SpinalAdapt experimental session.
%
%   Revised 2026-09-18: 13 conditions (1 tied fastest-speed trial, 2
%   pre-adaptation bouts trials, 5 adaptation split bouts trials, 5
%   post-adaptation bouts trials). The overground 6-minute walk test now
%   runs first and sets the belt speeds for every other trial (via
%   utils.extractSpeedsNMWT). Familiarization trials were removed. The
%   tied fastest-speed trial runs on the plain open-loop audio-countdown
%   controller (no fNIRS or H-reflex at that point in the session) and
%   is followed immediately by the next condition, with no break; every
%   other bout-based trial is followed by a fixed ~2.5 min break (none
%   after the final condition). Verify all conditions against the final
%   approved protocol before data collection. See History-PilotStudy2/
%   for the Pilot Study 2 original.
%
%   Revised again 2026-09-18 for the two-visit stroke protocol
%   (participant ID ending 'V01'/'V02'): visit 1 runs the 6-minute walk
%   test and generates every profile, including both possible fast-leg
%   assignments of the adaptation split profile
%   (AdaptSplitFastR.mat/AdaptSplitFastL.mat -- see
%   GENERATEPROFILES_SPINALADAPTBOUTS). Visit 2 skips the walk test and
%   profile regeneration entirely and loads visit 1's profiles directly
%   from visit 1's own profile folder, selecting whichever split profile
%   matches its own (flipped) fast-leg confirmation. Visit 2 never
%   writes a profile folder of its own, so
%   TRANSFERDATA_SPINALADAPTBOUTS (called unmodified at the end of each
%   visit) naturally transfers the speed profiles to the server only
%   once, at the end of visit 1.
%
%   Guides the experimenter through the 6-minute walk test, profile
%   generation, pre- and post-session H-reflex calibration trials, all
%   conditions in sequence, and post-session data transfer to the
%   server. Edit the EXPERIMENTER section below before each session run.
%
% Toolbox Dependencies:
%   None (external: AdaptationGUI, Vicon Nexus, labTools dataMotion)
%
% See also GENERATEPROFILES_SPINALADAPTBOUTS,
%   GENERATEPROFILE_SIXMINUTEWALK, RUNWALKINGCALIBRATIONS,
%   TRANSFERDATA_SPINALADAPTBOUTS.

%% EXPERIMENTER: Enter Subject-Specific Parameters Before Each Session
speedProportion        = 0.5;  % slow / 6MWT speed ratio
speedProportionFastest = 1.5;  % fastest / 6MWT speed ratio

% for stroke participants use SASS01V01 (Sub##V## format)
subjectID = 'SAYA01';   % SAYA##V## for young, SASS##V## for stroke, SAMC

fastLeg = 'R'; % 'R' or 'L'; for healthy: dominant leg; for stroke:
% non-paretic (session 1) or paretic (session 2).

dirProfile = fullfile( ...
    'C:\Users\Public\Documents\MATLAB\ExperimentalGUI', ...
    'profiles', 'SpinalAdaptNirsStudy', subjectID);

% date threshold for copying recent files in datlogs
threshTime = datetime('now', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

%% Confirm Fast Leg Assignment
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
% First trial of the session: sets the belt speeds used for every other
% trial (see Compute Speeds and Generate Speed Profiles below). Not one
% of the 13 numbered conditions in the switch further down. Guarded by a
% questdlg so resuming a session mid-way does not force a redundant
% six-minute walk. Self-paced (NaN profile) -- answer 'No' to the audio
% feedback prompt below so the participant walks at their own pace.
runWalkTest = questdlg(['Run the overground 6-minute walk test now? ' ...
    'Select No if resuming a session and it is already done.']);
if strcmp(runWalkTest, 'Yes')
    generateProfile_SixMinuteWalk(dirProfile);
    handles.popupmenu2.set('Value', ctrlSlotOgWalkTest);
    profilename = fullfile(dirProfile, 'SixMinuteWalk.mat');
    manualLoadProfile([], [], handles, profilename);
    answer = questdlg(['Confirm controller is Overground audio speed ' ...
        'feedback and profile is SixMinuteWalk. When prompted for ' ...
        'audio feedback, answer No (self-paced 6-minute walk test).']);
    if ~strcmp(answer, 'Yes')
        return;
    end
    AdaptationGUI('Execute_button_Callback', ...
        handles.Execute_button, [], handles);
    % manually stop in the GUI once six minutes of walking have elapsed
elseif isempty(runWalkTest)
    return;         % Cancel/closed: end the experiment
end
% 'No' falls through here: skip the walk test, continue to speed setup

%% Compute Speeds and Generate Speed Profiles
% The walk-test speeds are only needed to (re)generate profiles, so
% 'utils.extractSpeedsNMWT' is called only in the 'Yes' branch below
% (after the walk test above), not unconditionally at the top of the
% script -- letting a resumed session skip this dialog entirely.
opts.Interpreter = 'none';
opts.Default     = 'No, I generated them already';
profileToGen = questdlg(['Regenerate profile? Confirm subject ID ' ...
    'and fast leg are correct in RunProtocol_SpinalAdaptBouts.m, ' ...
    'and that the 6-minute walk test above is complete.'], ...
    'RegenProfile', 'Yes', 'No, I generated them already', opts);
switch profileToGen
    case 'Yes'
        answer = questdlg(['Just to double check: now create profile ' ...
            'where the fast leg is ' fastLeg ' Is that correct?']);
        if ~strcmp(answer, 'Yes')
            return;     % abort: fix fast leg assignment
        end
        speedNMWT    = utils.extractSpeedsNMWT();
        slowSpeed    = speedNMWT * speedProportion;
        fastSpeed    = speedNMWT;
        fastestSpeed = speedNMWT * speedProportionFastest;
        fprintf(['NMWT speed: %.3f m/s | slow: %.3f m/s | fast: ' ...
            '%.3f m/s | fastest: %.3f m/s\n'], speedNMWT, slowSpeed, ...
            fastSpeed, fastestSpeed);
        generateProfiles_SpinalAdaptBouts(slowSpeed, fastSpeed, ...
            fastestSpeed, dirProfile, fastLeg);
    case 'No, I generated them already'
        disp('Profile generated already. Continue with the experiments');
    otherwise
        disp('No response given, quit the script now.');
        return;
end

%% Complete Pre-Session H-Reflex Walking Calibration Trials
speedDefault  = 'Slow'; % protocol order: slow calibration trial first
isCalibration = true;   % run at least once (slow & fast speeds)
while isCalibration     % repeat until experimenter selects 'No'
    isCalibration = runWalkingCalibrations(handles, dirProfile, ...
        speedDefault);
    speedDefault = 'Fast'; % after the slow trial, default to fast
end

%% Run the Main SpinalAdapt Protocol Conditions
% NOTE: audio cues for "TM will start / stop now" are approximate and
% may be difficult to improve given the GUI callback latency.
isFirstCon = true;      % is this the first condition in the session?
currCon    = 0;         % current condition index; loop runs while < maxCon
while currCon < maxCon
    if ~isFirstCon      % after 1st condition, ask whether to auto-advance
        nextConButton = questdlg(['Would you like to automatically ' ...
            'continue with the next condition?']);
        if strcmp(nextConButton, 'Yes')
            currCon = currCon + 1;
        elseif strcmp(nextConButton, 'No')
            currCon = inputdlg(['Which condition do you want to start' ...
                ' from (1 = Tied fastest, 2 = Pre-adapt fast, ' ...
                '3 = Pre-adapt slow, 4 = 1st adaptation split, ' ...
                '9 = 1st post-adaptation, enter the number from the ' ...
                '1st col on the data sheet)?']);
            disp(['Starting from condition #' currCon{1}]);
            currCon = str2double(currCon{1});
        else
            return;     % cancel: end the experiment
        end
    else
        isFirstCon = false;
        currCon = inputdlg(['Which condition do you want to start' ...
            ' from (1 = Tied fastest, 2 = Pre-adapt fast, ' ...
            '3 = Pre-adapt slow, 4 = 1st adaptation split, ' ...
            '9 = 1st post-adaptation, enter the number from the 1st ' ...
            'col on the data sheet)?']);
        disp(['Starting from condition #' currCon{1}]);
        currCon = str2double(currCon{1});
    end

    switch currCon
        case 1          % Tied Fastest (150% of 6MWT, no ramp, no stim)
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'TiedFastest.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is TiedFastest']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for ~90 s wall clock
            play(AudioTimeUp);
        case 2          % Pre-Adaptation Fast (tied, 100% of 6MWT)
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'PreAdaptFast.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is PreAdaptFast']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for ~90 s wall clock
            play(AudioTimeUp);
        case 3          % Pre-Adaptation Slow (tied, 50% of 6MWT)
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'PreAdaptSlow.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is PreAdaptSlow']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for ~90 s wall clock
            play(AudioTimeUp);
        case {4, 5, 6, 7, 8}    % Adaptation Split Bouts 1-5
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'AdaptSplit.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is AdaptSplit']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for ~90 s wall clock
            play(AudioTimeUp);
        case {9, 10, 11, 12, 13}   % Post-Adaptation Slow Bouts 1-5
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            profilename = fullfile(dirProfile, 'PostAdaptSlow.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is PostAdaptSlow']);
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
isCalibration = runWalkingCalibrations(handles, dirProfile, 'Slow');

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
