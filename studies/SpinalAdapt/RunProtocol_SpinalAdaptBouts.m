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

%% EXPERIMENTER: Enter Participant-Specific Parameters Before Each Session
speedProportion        = 0.5;  % slow / 6MWT speed ratio
speedProportionFastest = 1.5;  % fastest / 6MWT speed ratio

% for stroke participants use SASS01V01 (Part##V## format)
participantID = 'SAYA01'; % SAYA##V## young, SASS##V## stroke, SAMC

fastLeg = 'R'; % 'R' or 'L'; for healthy: dominant leg; for stroke:
% non-paretic (visit 1) or paretic (visit 2).

% Two-visit stroke protocol: visit 2 reuses visit 1's profiles (speeds
% and both fast-leg split variants) directly from visit 1's own profile
% folder, so it never generates or writes a profile folder of its own.
% participantID itself (WITH the visit suffix) is kept for datlog/
% session naming and server transfer, since each visit's raw capture is
% its own session.
isVisit2 = contains(participantID, 'V02');
dirExpGUI = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI';
if isVisit2
    dirProfile = fullfile(dirExpGUI, 'profiles', 'SpinalAdaptNirsStudy', ...
        regexprep(participantID, 'V\d+$', 'V01'));
else
    dirProfile = fullfile(dirExpGUI, 'profiles', 'SpinalAdaptNirsStudy', ...
        participantID);
end

% date threshold for copying recent files in datlogs
threshTime = datetime('now', 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

%% Confirm Fast Leg Assignment
answer = 'Yes';                     % default to 'yes', don't check it
if contains(participantID, 'V01')
    answer = questdlg(['Visit 1: Fast leg should be NON-paretic / ' ...
        'Dominant leg, which is ' fastLeg ' Is that correct?']);
elseif isVisit2
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

maxCon                 = 13;  % maximum number of conditions
pauseBetweenTrials     = 115; % s; 2.5 min wall clock including the ~35 s
                               % Vicon stop/start delay; applied after
                               % every bout-based condition except the
                               % last (see the main switch below)
ctrlSlotNirsHreflex    = 14;  % GUI slot: NIRS/H-reflex controller (see
                               % NirsHreflexArduinoOpenLoopWithAudio)
ctrlSlotAudioCountDown = 11;  % GUI slot: audio-countdown controller,
                               % no fNIRS/H-reflex (see
                               % controlSpeedWithSteps_edit1_
                               % AudioCountDown)
ctrlSlotOgWalkTest     = 8;   % GUI slot: HreflexOGWithAudio, no stim
pauseTransferSec       = 60;  % s; allows Vicon to stop and save last trial

%% Complete Overground 6-Minute Walk Test
% First trial of the session: sets the belt speeds used for every other
% trial (see Compute Speeds and Generate Speed Profiles below). Not one
% of the 13 numbered conditions in the switch further down. Guarded by a
% questdlg so resuming a session mid-way does not force a redundant
% six-minute walk. Self-paced (NaN profile) -- answer 'No' to the audio
% feedback prompt below so the participant walks at their own pace.
% Skipped entirely for visit 2 of the two-visit stroke protocol: the
% walk test is only ever completed in visit 1, and visit 2 reuses those
% speeds (see Compute Speeds and Generate Speed Profiles below).
if isVisit2
    disp(['Visit 2: the 6-minute walk test is only completed in ' ...
        'visit 1; skipping.']);
else
    runWalkTest = questdlg(['Run the overground 6-minute walk test ' ...
        'now? Select No if resuming a session and it is already done.']);
    if strcmp(runWalkTest, 'Yes')
        generateProfile_SixMinuteWalk(dirProfile);
        handles.popupmenu2.set('Value', ctrlSlotOgWalkTest);
        profilename = fullfile(dirProfile, 'SixMinuteWalk.mat');
        manualLoadProfile([], [], handles, profilename);
        answer = questdlg(['Confirm controller is Overground audio ' ...
            'speed feedback and profile is SixMinuteWalk. When ' ...
            'prompted for audio feedback, answer No (self-paced ' ...
            '6-minute walk test).']);
        if ~strcmp(answer, 'Yes')
            return;
        end
        AdaptationGUI('Execute_button_Callback', ...
            handles.Execute_button, [], handles);
        % manually stop in the GUI once six minutes of walking have
        % elapsed
    elseif isempty(runWalkTest)
        return;         % Cancel/closed: end the experiment
    end
    % 'No' falls through here: skip the walk test, continue to speed
    % setup
end

%% Compute Speeds and Generate Speed Profiles
% The walk-test speeds are only needed to (re)generate profiles, so
% 'utils.extractSpeedsNMWT' is called only in the 'Yes' branch below
% (after the walk test above), not unconditionally at the top of the
% script -- letting a resumed session skip this dialog entirely.
if isVisit2
    % Visit 2 never regenerates: it loads visit 1's profiles (same
    % speeds, both fast-leg split variants already generated) directly
    % from visit 1's own profile folder (dirProfile above already points
    % there). Verify they are actually there rather than silently
    % pointing at an empty folder if e.g. participantID was mistyped or
    % visit 1 was never run.
    expectedProfiles = {'TiedFastest.mat', 'PreAdaptFast.mat', ...
        'PreAdaptSlow.mat', 'PostAdaptSlow.mat', 'AdaptSplitFastR.mat', ...
        'AdaptSplitFastL.mat', 'CalibrationSlow.mat', ...
        'CalibrationFast.mat'};
    isProfileMissing = ~cellfun(@(f) ...
        exist(fullfile(dirProfile, f), 'file') == 2, expectedProfiles);
    if ~exist(dirProfile, 'dir') || any(isProfileMissing)
        errordlg(['Visit 2: expected profile(s) from visit 1 not ' ...
            'found in ' dirProfile ' (missing: ' ...
            strjoin(expectedProfiles(isProfileMissing), ', ') '). Run ' ...
            'visit 1 first, or check that participantID matches ' ...
            'visit 1.']);
        return;
    end
    disp(['Visit 2: reusing visit 1 profiles found in ' dirProfile]);
else
    opts.Interpreter = 'none';
    opts.Default     = 'No, I generated them already';
    profileToGen = questdlg(['Regenerate profile? Confirm ' ...
        'participant ID is correct in RunProtocol_SpinalAdaptBouts.m,' ...
        ' and that the 6-minute walk test above is complete.'], ...
        'RegenProfile', 'Yes', 'No, I generated them already', opts);
    switch profileToGen
        case 'Yes'
            speedNMWT    = utils.extractSpeedsNMWT();
            slowSpeed    = speedNMWT * speedProportion;
            fastSpeed    = speedNMWT;
            fastestSpeed = speedNMWT * speedProportionFastest;
            fprintf(['NMWT speed: %.3f m/s | slow: %.3f m/s | fast: ' ...
                '%.3f m/s | fastest: %.3f m/s\n'], speedNMWT, ...
                slowSpeed, fastSpeed, fastestSpeed);
            generateProfiles_SpinalAdaptBouts(slowSpeed, fastSpeed, ...
                fastestSpeed, dirProfile);
        case 'No, I generated them already'
            disp(['Profile generated already. Continue with the ' ...
                'experiments']);
        otherwise
            disp('No response given, quit the script now.');
            return;
    end
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
            % No fNIRS or H-reflex during this trial: runs on the plain
            % open-loop audio-countdown controller (shared with C3/
            % BrainWalk), not the NIRS/H-reflex controller used by every
            % other condition below. It speaks its own "treadmill will
            % start/stop in 3-2-1" warning (numAudioCountDown = -1, the
            % default) since no fNIRS headband is on yet.
            handles.popupmenu2.set('Value', ctrlSlotAudioCountDown);
            profilename = fullfile(dirProfile, 'TiedFastest.mat');
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TiedFastest']);
            if ~strcmp(answer, 'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            % no break here -- proceed immediately to the next condition
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
            pause(pauseBetweenTrials);  % break for 2.5 min wall clock
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
            pause(pauseBetweenTrials);  % break for 2.5 min wall clock
            play(AudioTimeUp);
        case {4, 5, 6, 7, 8}    % Adaptation Split Bouts 1-5
            handles.popupmenu2.set('Value', ctrlSlotNirsHreflex);
            % AdaptSplitFastR/AdaptSplitFastL: both fast-leg assignments
            % were generated in visit 1 (see
            % GENERATEPROFILES_SPINALADAPTBOUTS); pick the one matching
            % this visit's confirmed fastLeg above.
            profilename = fullfile(dirProfile, ...
                sprintf('AdaptSplitFast%s.mat', fastLeg));
            manualLoadProfile([], [], handles, profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop with audio and profile is AdaptSplitFast' ...
                fastLeg]);
            if ~strcmp(answer, 'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button, [], handles);
            pause(pauseBetweenTrials);  % break for 2.5 min wall clock
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
            if currCon < maxCon         % no break after the final block
                pause(pauseBetweenTrials);  % break for 2.5 min wall clock
                play(AudioTimeUp);
            end
    end
end

%% Complete End-of-Session H-Reflex Walking Calibration Trials
isCalibration = runWalkingCalibrations(handles, dirProfile, 'Slow');

%% Transfer Session Data to Server
% pauseTransferSec allows Vicon Nexus to stop and save the last C3D file
pause(pauseTransferSec);
tic;
transferData_SpinalAdaptBouts(participantID, threshTime);
toc;

%% Run Reconstruct and Label Pipeline and Fill Marker Gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLY RUN THIS BLOCK ON THE LAB PC1 IF THERE IS SUFFICIENT TIME BEFORE
% THE NEXT EXPERIMENTER NEEDS THE LAB SPACE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% participantID (with its visit suffix) keeps this path distinct per
% visit for the two-visit stroke protocol, matching
% TRANSFERDATA_SPINALADAPTBOUTS's own per-visit dirSrvrData.
tic;
dirSrvrData = fullfile('W:\SpinalAdaptStudy\Data', participantID, 'Vicon');
dataMotion.processAndFillMarkerGapsSession(dirSrvrData);
toc;
