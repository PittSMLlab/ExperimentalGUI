% author: SL
% This script will:
%   1) generate speed profiles for the SpinalAdapt Study, which requires
%   the experimenter to manually input the subjectID, fast speed and leg,
%   and any other parameters desired.
%   2) automate the experimental flow for the TMBase fast, slow and then
%   break for OG (needs experimenter input for speed feedback range)
%   3) automate the experimental flow from pre nirs train, then adaptation
%   blocks, then post train, finish with pos and negative short.
%   OG baseline conditions (3-5) will be run manually because OG with speed
%   feedback need different speed range --> this will require manual change
%   before each condition.

%% EXPERIMENTER: Before each experiment, ENTER subject-specific speed and leg info
ramp2Split = false; % SAH1-16 ramp2Split= true, also there was an coding error such that
% 1st train 1st tied-split only has 10 strides tied before split instead of 20 tied as planned in the protocol,
% Starting 7/8/2024 try the non-ramp version and also corrected the mistake
% so 1st train has 20 strides tied before split.
speedRatio = 0.7; %slow/fast, SAH 1-16 did speedRatio = 0.5; %starting 7/8/2024, try ratio 1:0.7

% for stroke participant use SAS01V01 (Sub##V## format)
subjectID = 'ShuqiPractice';    % SAH01 for young, SAS01V01 for stroke
% To use the GUI to automatically compute the 6MWT speed, call
%   utils.extractSpeedsNMWT();
% and update the 'fast' speed below with output value
fast = 1.1;     % speed m/s
%if 2:1 ratio, slow=0.5*fast, if 70%, slow = 0.7*fast
slow = fast * speedRatio;

fastLeg = 'R';%Allowed entries: R or L, if don't know yet, leave as random and choose generate baseline only
%for healthy controls, fast = dominant
%for stroke participant, fast = non-paretic for session1 amd fast = paretic
%for session 2.

% date threshold for copying recent files in datlogs
threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss');

%% Generate Baseline or Adaptation Speed Profiles from Experimenter Input
profileDir = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\' ...
    'profiles\SpinalAdaptNirsStudy\' subjectID filesep];
button = 'Yes';                     % default to 'yes' don't check it
if contains(subjectID,'V01')        % 2 visits detected, this is visit 1
    button = questdlg(['Stroke Session 1: Fast leg should be ' ...
        'NON-paretic leg, which is ' fastLeg ' Is that correct?']);
elseif contains(subjectID,'V02')    % 2 visits detected, this is visit 2
    button = questdlg(['Stroke Session 2: Fast leg should be paretic ' ...
        'leg, which is ' fastLeg ' Is that correct?']);
end
if ~strcmp(button,'Yes')
    return;  % Abort starting, fix the fast leg assignment.
end

opts.Interpreter = 'tex';
opts.Default = 'No, I generated them already';
profileToGen = questdlg(['Regenerate profile? Confirm speed and ' ...
    'subject ID are correct in SpinalAdaptProtocol.m '],'RegenProfile', ...
    'Yes','No, I generated them already',opts);
switch profileToGen
    case 'Yes'
        % confirm again the fast leg is correct
        button = questdlg(['Just to double check: now create profile ' ...
            'where the fast leg is ' fastLeg ' Is that correct?']);
        if ~strcmp(button,'Yes')
            return;  % Abort starting the trial
        end
        % generate baseline speed profiles only
        GenerateProfileSpinalStudy(slow, fast, true, profileDir);
        % generate rest of profiles after determining dominant leg & ramp
        GenerateProfileSpinalStudy(slow, fast, false, profileDir, ...
            fastLeg, ramp2Split);
    case 'No, I generated them already'
        % continue.
        disp('Profile generated already. Continue with the experiments');
    otherwise
        disp('No response given, quit the script now.');
        return;
end

%% Set Up the GUI & Run the Experiment
% load audio file for announcing the end of the break
% [audio_data,audio_fs]=audioread('TimeIsUp.mp3');
[audio_data,audio_fs] = audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

% load AdapationGUI and get the GUI figure handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown
global isCalibration

maxCond = 17;
% below times (in seconds) account for delays due to Vicon stop/start time
pauseTime2min30 = 115;
pauseTime1min = 40;
% pauseTime5m = 265;

%% 1st check if should go through calibration routine
% isDoneCalib = false;
% while ~isDoneCalib
isCalibBtn = questdlg(['Do you want to run a Hreflex walking ' ...
    'calibration trial?']);
if strcmp(isCalibBtn,'Yes') % run dynamic (i.e., walking) calibration
    isCalibration = true;
    handles.popupmenu2.set('Value',14)  % NirsHreflexOpenLoopWithAudio
    opts.Interpreter = 'tex';
    opts.Default = 'Slow';
    profileToGen = questdlg(['What TM speed to calibrate on? (Default '
        'is slow)'],'','Fast','Slow',opts); % default choose slow
    switch profileToGen
        case 'Fast'
            profilename = [profileDir 'CalibrationFast.mat'];
            disp('Run Hreflex calibration with fast TM walking speed.');
        case 'Slow'
            profilename = [profileDir 'CalibrationSlow.mat'];
            disp('Run Hreflex calibration with slow TM walking speed.');
        otherwise
            disp('No response given, quit the script now.');
            return
    end
    manualLoadProfile([],[],handles,profilename);
    AdaptationGUI( ...
        'Execute_button_Callback',handles.Execute_button,[],handles);
    %     else
    %        isDoneCalib = true; %
end
% end

%% Start the Main Portion of the Experimental Protocol
%the TM will start now/ stop now is not exactly on point but maybe not
%easy to make it better.
isCalibration = false; %reset iscalib to false.
firstCond = true;
currCond = 0; %default value to start while loop.
while currCond < maxCond
    if ~firstCond
        nextCondButton=questdlg('Auto continue with next condition?');
        if strcmp(nextCondButton,'Yes') %automatically advance to next condition.
            currCond = currCond + 1;
            if contains(subjectID,'SAH') && ismember(currCond,[3,4]) %Healthy young people & OG trials now
                currCond = 5; %skip OG for young adults, start from 5 (pre train)
            end
        elseif strcmp(nextCondButton, 'No')
            %if said No to auto advance, ask where to start
            currCond = inputdlg('Which condition to start from (1 for baseline, 5 for pretrain, enter the number from the 1st col on the data sheet)? ');
            currCond = str2num(currCond{1});
            disp(['Starting from ' num2str(currCond)]);
        else %cancel
            return %stop exp
        end
    else
        firstCond = false;
        %always ask the first time.
        currCond = inputdlg('Which condition to start from (1 for baseline, 5 for pretrain, enter the number from the 1st col on the data sheet)? ');
        currCond = str2num(currCond{1});
        disp(['Starting from ' num2str(currCond)]);
    end

    switch currCond
        case 1 %TM base tied
            handles.popupmenu2.set('Value',14) %Nirs, Hreflex, Open Loop with count down.
            profilename = [profileDir, 'TMBaseFast.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Nirs, Hreflex, Open loop controller with audio countdown and profile is TMBaseFast');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 2 %TM base slow
            handles.popupmenu2.set('Value',14) %Nirs, Hreflex, OPEN Loop with count down.
            profilename = [profileDir, 'TMBaseSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Nirs, Hreflex, Open loop controller with audio countdown and profile is TMBaseSlow');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {3} %OG Fast
            handles.popupmenu2.set('Value',16) %OG Audio with HreflexOGWithAudio
            profilename = [profileDir 'OGBaseFast.mat'];
            manualLoadProfile([],[],handles,profilename)
            %now will ask user to change the speed info.
            button=questdlg('Confirm controller is HreflexOGWithAudio and speed profile is fast');
            if ~strcmp(button,'Yes')
                return; %Always return and quit because now needs experimenter change in OG controller for the next 3 trials.
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {4} %OG Slow
            handles.popupmenu2.set('Value',16) %OG Audio with Hreflex
            profilename = [profileDir 'OGBaseSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            %now will ask user to change the speed info.
            button=questdlg('Confirm controller is HreflexOGWithAudio and speed profile is slow');
            if ~strcmp(button,'Yes')
                return; %Always return and quit because now needs experimenter change in OG controller for the next 3 trials.
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {5,6} %ctrl train
            handles.popupmenu2.set('Value',14) %NIRS train
            if currCond == 5 %1st ctrl train
                profilename = [profileDir 'CtrlTrain_1.mat'];
            else
                profilename = [profileDir 'CtrlTrain_2.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: Nirs Train Control?');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime2min30); %break for 5mins at least.
            play(AudioTimeUp);
        case {7,8} %pre train
            handles.popupmenu2.set('Value',14) %NIRS train
            if currCond == 5 %1st pre train
                profilename = [profileDir 'PreSplitTrain_1.mat'];
            else
                profilename = [profileDir 'PreSplitTrain_2.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: Nirs Train Pre?');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime2min30); %break for 5mins at least.
            play(AudioTimeUp);
        case {14,15} %post nirs train
            handles.popupmenu2.set('Value',14) %NIRS train
            if currCond == 14 %1st post train
                profilename = [profileDir 'PostSplitTrain_1.mat'];
            else
                profilename = [profileDir 'PostSplitTrain_2.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: Nirs Train Post?');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            %             if currCond == 12 %only time break for 1st train.
            pause(pauseTime2min30); %break for 5mins at least.
            play(AudioTimeUp);
            %             end
        case {9,13} %end adapt
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'Adapt1And5.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is Adapt');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime2min30); %~2.5mins
            play(AudioTimeUp);
        case {10,11,12}   % middle adapt
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'Adapt234.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is Adapt');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime2min30); %~2.5mins
            play(AudioTimeUp);
        case 16 %post 1
            handles.popupmenu2.set('Value',14) %open loop with countdown with NIRS
            profilename = [profileDir 'Post1.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is Post-Adapt 200 strides');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime1min); %~2.5mins
            play(AudioTimeUp);
        case 17 %post 2
            handles.popupmenu2.set('Value',14) %NIRS open loop with countdown
            profilename = [profileDir 'Post2.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is Post-Adapt 100 strides with rest');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime1min); %~2.5mins
            play(AudioTimeUp);
        case 18 %neg short first
            handles.popupmenu2.set('Value',11) %open loop with countdown
            profilename = [profileDir 'NegShort.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is NegShort');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [50 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime1min); %~2.5mins
            play(AudioTimeUp);
        case 19 %then pos short
            handles.popupmenu2.set('Value',11) %open loop with countdown
            profilename = [profileDir 'PosShort.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is PosShort');
            if ~strcmp(button,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [100 130 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
    end
end

%% Transfer the Data After the Experiment Has Finished
% TODO: uncomment after verifying 'transferData_SpinalAdapt' function
% tic;
% transferData_SpinalAdapt(subjectID,threshTime);
% toc;

%% Run Reconstruct & Label Pipeline & Automatically Fill Small Marker Gaps
% TODO: uncomment after verifying works properly
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLY RUN THIS BLOCK ON THE LAB PC1 IF THERE IS SUFFICIENT TIME BEFORE THE
% NEXT EXPERIMENTER NEEDS THE LAB SPACE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tic;
% % TODO: will need to update path below for participants with stroke (i.e.,
% % multiple behavioral visits)
% dirSrvrData = fullfile('W:\SpinalAdaptStudy\Data',subjectID,'Vicon');
% dataMotion.processAndFillSmallMarkerGapsSession(dirSrvrData);
% % dataMotion.reconstructAndLabelSession(dirSrvrData);
% toc;

