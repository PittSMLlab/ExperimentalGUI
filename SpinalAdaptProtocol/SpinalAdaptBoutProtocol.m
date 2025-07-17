% author(s): SL, NWB
% purpose: to automate the experimental flow by generating the speed / stim
% profiles, which requires the experimenter to input parameters, choosing
% the correct order of the conditions / trials and the correct controllers
% and profiles.

%% EXPERIMENTER: Before each experiment, ENTER subject-specific speed and leg info
ramp2Split = false; % SAH1-16 ramp2Split= true, also there was an coding error such that
% 1st train 1st tied-split only has 10 strides tied before split instead of 20 tied as planned in the protocol,
% Starting 7/8/2024 try the non-ramp version and also corrected the mistake
% so 1st train has 20 strides tied before split.
speedRatio = 0.7; %slow/fast, SAH 1-16 did speedRatio = 0.5; %starting 7/8/2024, try ratio 1:0.7

% for stroke participant use SAS01V01 (Sub##V## format)
subjectID = 'SABH06';    % SAH01 for young, SAS01V01 for stroke
% To use the GUI to automatically compute the 6MWT speed, call
%   utils.extractSpeedsNMWT();
% and update the 'fast' speed below with output value
fast = 1.3963;     % speed m/s
%if 2:1 ratio, slow=0.5*fast, if 70%, slow = 0.7*fast
slow = fast * speedRatio;

fastLeg = 'R';%Allowed entries: R or L, if don't know yet, leave as random and choose generate baseline only
%for healthy controls, fast = dominant
%for stroke participant, fast = non-paretic for session1 amd fast = paretic
%for session 2.

% date threshold for copying recent files in datlogs
threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss');

%% Generate Baseline or Adaptation Speed Profiles from Experimenter Input
dirProfile = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\' ...
    'profiles\SpinalAdaptNirsStudy\' subjectID];
answer = 'Yes';                     % default to 'yes', don't check it
if contains(subjectID,'V01')        % 2 visits detected, this is visit 1
    answer = questdlg(['Stroke Session 1: Fast leg should be ' ...
        'NON-paretic leg, which is ' fastLeg ' Is that correct?']);
elseif contains(subjectID,'V02')    % 2 visits detected, this is visit 2
    answer = questdlg(['Stroke Session 2: Fast leg should be paretic ' ...
        'leg, which is ' fastLeg ' Is that correct?']);
end
if ~strcmp(answer,'Yes')
    return;             % abort starting, first fix the fast leg assignment
end

opts.Interpreter = 'tex';
opts.Default = 'No, I generated them already';
profileToGen = questdlg(['Regenerate profile? Confirm speed and ' ...
    'subject ID are correct in SpinalAdaptProtocol.m '],'RegenProfile', ...
    'Yes','No, I generated them already',opts);
switch profileToGen
    case 'Yes'
        % confirm again the fast leg is correct
        answer = questdlg(['Just to double check: now create profile ' ...
            'where the fast leg is ' fastLeg ' Is that correct?']);
        if ~strcmp(answer,'Yes')
            return;     % abort starting the trial
        end
        % generate baseline speed profiles only
        GenerateProfileSpinalBoutStudy(slow, fast, true, dirProfile);
        % generate rest of profiles after determining dominant leg & ramp
        GenerateProfileSpinalBoutStudy(slow, fast, false, dirProfile, ...
            fastLeg, ramp2Split);
    case 'No, I generated them already'
        % continue
        disp('Profile generated already. Continue with the experiments');
    otherwise
        disp('No response given, quit the script now.');
        return;
end

%% Set Up the GUI & Run the Experiment
% load audio file for announcing the end of the break
[audio_data,audio_fs] = audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

% load AdapationGUI and get the GUI figure handle
handles = guidata(AdaptationGUI);

% NOTE: these variables are needed as controller function input arguments
global profilename
global numAudioCountDown
global isCalibration

maxCon = 13;            % maximum number of conditions
% below times (in seconds) account for delays due to Vicon stop/start time
pauseTime1min = 40;
pauseTime2min30 = 115;

%% Complete Pre-Session H-Reflex Walking Calibration Trials
isCalibration = true;   % run this block at least once (slow & fast trials)
while isCalibration     % repeat calibrations until select 'No'
    isCalibration = runWalkingCalibrations(handles,dirProfile);
end

%% Start the Main Portion of the Spinal Adaptation Experimental Protocol
% NOTE: audio cues indicating TM will start now / stop now is not precise,
% but it may be difficult to improve.
% isCalibration = false;    % reset
isFirstCon = true;          % is first condition in experiment?
currCon = 0;                % initialize current condition to start loop
while currCon < maxCon      % while more conditions left to collect, ...
    if ~isFirstCon          % if not first condition, ...
        % ask experimenter whether to continue to the next condition
        nextConButton = questdlg(['Would you like to automatically ' ...
            'continue with the next condition?']);
        if strcmp(nextConButton,'Yes')  % automatically advance to next
            currCon = currCon + 1;      % increment to next condition
            if contains(subjectID,'SABH') && ismember(currCon,[3 4])
                currCon = 5;            % skip OG trials for young adults
            end
        elseif strcmp(nextConButton,'No')
            % if selected 'No' to automatically advance, ...
            currCon = inputdlg(['Which condition do you want to start' ...
                ' from (1 = baseline, 5 = control train, 7 = 1st split' ...
                ' train, enter the number from the first column on the' ...
                ' data sheet)?']);      % ask experimenter which condition
            disp(['Starting from condition #' currCon{1}]);
            currCon = str2double(currCon{1});
        else                % otherwise, terminate script
            return;         % end the experiment
        end
    else                    % otherwise, ...
        isFirstCon = false;             % no longer first condition after
        currCon = inputdlg(['Which condition do you want to start ' ...
            'from (1 = baseline, 5 = control train, 7 = 1st split ' ...
            'train, enter the number from the 1st col on the data ' ...
            'sheet)?']);
        disp(['Starting from condition #' currCon{1}]);
        currCon = str2double(currCon{1});
    end

    switch currCon
        case 1          % TM Baseline Fast (Tied)
            % fNIRS, H-reflex, open-loop controller with audio count down
            handles.popupmenu2.set('Value',14);
            profilename = fullfile(dirProfile,'TMBaseFast.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop controller with audio countdown and profile' ...
                ' is TMBaseFast']);
            if ~strcmp(answer,'Yes')% if incorrect controller/profile, ...
                return;             % abort starting experiment
            end
            numAudioCountDown = -1; % include final audio countdown
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case 2          % TM Baseline Slow (Tied)
            handles.popupmenu2.set('Value',14);
            profilename = fullfile(dirProfile,'TMBaseSlow.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Nirs, Hreflex, ' ...
                'Open loop controller with audio countdown and profile' ...
                ' is TMBaseSlow']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case 3          % OG Baseline Fast
            % OG audio with H-reflex controller
            handles.popupmenu2.set('Value',16);
            profilename = fullfile(dirProfile,'OGBaseFast.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is ' ...
                'HreflexOGWithAudio and speed profile is fast']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case 4          % OG Baseline Slow
            handles.popupmenu2.set('Value',16);
            profilename = fullfile(dirProfile,'OGBaseSlow.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is ' ...
                'HreflexOGWithAudio and speed profile is slow']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case {5,6}      % Control Train Bouts (Tied)
            handles.popupmenu2.set('Value',14);
            if currCon == 5        % first control train trial
                profilename = fullfile(dirProfile,'CtrlTrain_1.mat');
            elseif currCon == 6    % second control train trial
                profilename = fullfile(dirProfile,'CtrlTrain_2.mat');
            end
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm the trial information: Nirs ' ...
                'Train Control?']);
            if ~strcmp(answer,'Yes')
                return;
            end
            % numAudioCountDown = []; %If errors out in this condition, comment this out. -----Temp7/14/2025-----
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime2min30);     % break for at least 2.5 minutes
            play(AudioTimeUp);
        case {7,8,9,10,11}  % Split Train Bouts
            handles.popupmenu2.set('Value',14);
            profilename = fullfile(dirProfile, ...
                ['PreSplitTrain_' num2str(currCon-6) '.mat']);
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm the trial information: Nirs ' ...
                'Split Train?']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime2min30);     % break for at least 2.5 minutes
            play(AudioTimeUp);
        case 12             % Post-Train with Negative Short Split
            handles.popupmenu2.set('Value',14);
            profilename = fullfile(dirProfile,'Post1WtNegShort.mat');
            manualLoadProfile([],[],handles,profilename)
            answer = questdlg(['Confirm the trial information: post 1 ' ...
                '(50 tied fast, 30 negshort, 100 tied fast)?']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1; % [50 80 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime2min30);     % break for at least 2.5 minutes
            play(AudioTimeUp);
        case 13             % Final Post-Train (Tied)
            handles.popupmenu2.set('Value',14);
            profilename = fullfile(dirProfile,'Post2.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm trial and profile is Post 2 ' ...
                '(tied for 200)']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
    end
end

%% Complete End-of-Session H-Reflex Walking Calibration Trials
isCalibration = runWalkingCalibrations(handles,dirProfile);

%% Transfer the Data After the Experiment Has Finished
% pause for one minute to allow Vicon Nexus to stop and save last trial
pause(60);
tic;
transferData_SpinalAdapt(subjectID,threshTime);
toc;

%% Run Reconstruct & Label Pipeline & Automatically Fill Marker Gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLY RUN THIS BLOCK ON THE LAB PC1 IF THERE IS SUFFICIENT TIME BEFORE THE
% NEXT EXPERIMENTER NEEDS THE LAB SPACE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TODO: update path below for participants with stroke (i.e., two visits)
tic;
dirSrvrData = fullfile('W:\SpinalAdaptStudy\Data',subjectID,'Vicon');
dataMotion.processAndFillMarkerGapsSession(dirSrvrData);
toc;

