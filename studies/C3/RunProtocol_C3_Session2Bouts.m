% author: NWB
% date (created): 30 Mar. 2025
% purpose: to automate the experimental flow by choosing the correct order
% of the conditions / trials and the correct controllers and profiles.

%% Retrieve Participant Data from Experimenter
prompt = {['Enter the participant ID (''C3S##'' for participants with ' ...
    'stroke, ''C3C##'' for control participants, do NOT include ' ...
    '''_S#'' for the session):']};
dlgtitle = 'Participant Experimental Inputs';
fieldsize = [1 60];
definput = {'Test'};                                    % participant ID
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

% Extract Participant Experimental Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% comment out the above GUI block, and manually enter the desired values
% below (e.g., participantID = 'Test';) if preferred
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ID: C3S## for participants with stroke, C3C## for control participants
% NOTE: do NOT include '_S1' or '_S2' here to indicate session
participantID = answer{1};
% date threshold for copying recent files in datlogs
threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss');
isCtrl = startsWith(participantID,'C3C');

%% Identify Participant with Stroke for Whom Participant is Serving as Ctrl
if isCtrl
    prompt = { ...
        ['Enter the ID of the participant with stroke for whom this ' ...
        'participant is serving as a control (''C3S##'', do NOT ' ...
        'include ''_S#'' for the session):']};
    dlgtitle = 'Control Participant Input';
    fieldsize = [1 60];
    definput = {'Test'};                    % participant with stroke ID
    answer = inputdlg(prompt,dlgtitle,fieldsize,definput);
    participantID_Stroke = answer{1};
end

%% Generate Speed Profiles or Retrieve Profile Directory
dirBase = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\' ...
    'profiles\Stroke_CCC'];
if isCtrl                                   % if control participant, ...
    raw = dir(fullfile(dirBase,participantID_Stroke));  % retrieve folder
else
    raw = dir(fullfile(dirBase,participantID));
end
ignore = endsWith({raw.name},{'.','..'});   % remove current/parent
profiles = raw(~ignore);
% NOTE: there should only be one profile folder since the irrelevant
% one should have been deleted in session 1
if isempty(profiles)
    disp('There are no profiles found, quitting the script now.');
    return;
elseif length(profiles) > 1
    disp('There are two sets of profiles, quitting the script now.');
    return;
else
    disp('Continuing with the experiment.');
    if isCtrl                       % if control participant, ...
        dirProfile = fullfile(dirBase,participantID_Stroke, ...
            profiles.name);
    else                            % otherwise, participant w/ stroke
        dirProfile = fullfile(dirBase,participantID,profiles.name);
    end
end

%% Set Up the GUI & Run the Experiment
% load audio file for announcing the end of the break
[audio_data,audio_fs] = audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

% load AdapationGUI and get the GUI figure handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

maxTrials = 17;         % maximum number of trials
% below times (in seconds) account for delays due to Vicon start/stop time
pauseTime1min = 25;
pauseTime2min = 85;
pauseTime3min20sec = 165;

%% Start C3 Experimental Protocol
isFirstTrial = true;        % is first trial in experiment?
currTrial = 0;              % initialize current trial to start while loop
while currTrial < maxTrials % while more trials left to collect, ...
    if ~isFirstTrial        % if not the first trial, ...
        % ask experimenter whether to continue to next trial
        nextTrialButton = questdlg(['Would you like to automatically ' ...
            'continue with the next trial?']);
        if strcmp(nextTrialButton,'Yes')% automatically advance next trial
            currTrial = currTrial + 1;  % increment to next trial
        elseif strcmp(nextTrialButton,'No')
            currTrial = inputdlg(['Which trial do you want to start ' ...
                'from (enter the number from the 1st column on the ' ...
                'data sheet)?']);       % ask experimenter which trial
            currTrial = str2double(currTrial{1});
            disp(['Starting from trial #' num2str(currTrial)]);
        else                % otherwise, terminate script
            return;         % end the experiment
        end
    else                    % otherwise, ...
        isFirstTrial = false;           % no longer first trial after this
        currTrial = inputdlg(['Which trial do you want to start ' ...
            'from (enter the number from the 1st column on the ' ...
            'data sheet)?']);           % ask experimenter which trial
        currTrial = str2double(currTrial{1});
        disp(['Starting from trial #' num2str(currTrial)]);
    end

    % TODO: implement
    % 'runTrial(handles,nameTrial,pathProfile,indCtrlr,timesCountdown)'
    % function that can be used across protocols
    switch currTrial
        case 1          % TM Baseline Mid (Tied)
            % open-loop controller with audio count down
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Baseline_Mid1.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_Baseline_Mid1']);
            if ~strcmp(answer,'Yes')% if incorrect controller/profile, ...
                return;             % abort starting experiment
            end
            numAudioCountDown = -1; % include final audio countdown
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case 2          % TM Baseline Fast (Tied)
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Baseline_Fast.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_Baseline_Fast']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case 3          % OG Baseline Mid
            % overground controller with audio count down
            handles.popupmenu2.set('Value',8);
            profilename = fullfile(dirProfile,'OG_Baseline_Mid.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Overground ' ...
                'audio speed feedback and profile is OG_Baseline_Mid']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % no fixed break here - proceed immediately in GUI
        case 4          % TM Short Exposure Negative
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_ShortExposure_Neg.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_ShortExposure_Neg']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = [50 100 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime2min);       % break for at least two minutes
            play(AudioTimeUp);
        case 5          % TM Short Exposure Positive
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_ShortExposure_Pos.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_ShortExposure_Pos']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = [50 100 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime2min);
            play(AudioTimeUp);
        case 6          % TM Baseline Mid Full (Tied)
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Baseline_Mid2.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_Baseline_Mid2']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime2min);
            play(AudioTimeUp);
        case {7,8,9,10,11,12,13,14}      % TM Split Walking Bouts
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_SplitBout.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_SplitBout']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = [25 125 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            if currTrial == 11              % if trial 11, ...
                pause(pauseTime3min20sec);  % need more time for BP/HR
            else                            % otherwise, ...
                pause(pauseTime2min);       % default to two minutes
            end
            play(AudioTimeUp);
        case 15                             % Final TM Split Bout
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_SplitBout_Short.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_SplitBout_Short']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = [25 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime1min);           % short before post-adaptation
            play(AudioTimeUp);
        case 16                             % OG Post-Adaptation Long
            handles.popupmenu2.set('Value',8);
            profilename = fullfile(dirProfile,'PostAdaptation_Long.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Overground ' ...
                'audio speed feedback and profile is PostAdaptation_Long']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            pause(pauseTime3min20sec);      % need more time for BP/HR
            play(AudioTimeUp);
        case 17                             % OG Post-Adaptation
            handles.popupmenu2.set('Value',8);
            profilename = fullfile(dirProfile,'PostAdaptation.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Overground ' ...
                'audio speed feedback and profile is PostAdaptation']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
    end
end

%% Transfer the Data After the Experiment Has Finished
% pause for one minute to allow Vicon Nexus to stop and save last trial
pause(60);
tic;
transferData_PC1_C3(participantID,false,threshTime);
toc;

%% Run Reconstruct & Label Pipeline & Automatically Fill Marker Gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLY RUN THIS BLOCK ON THE LAB PC1 IF THERE IS SUFFICIENT TIME BEFORE THE
% NEXT EXPERIMENTER NEEDS THE LAB SPACE
% Duration: ~46 minutes for 17 trials (entire session)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;
dirSrvrData = fullfile('W:\Nathan\C3\Data',participantID,'Session2','PC1');
dataMotion.processAndFillMarkerGapsSession(dirSrvrData);
toc;

