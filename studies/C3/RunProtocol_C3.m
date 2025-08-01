% author: NWB
% date (created): 04 Sep. 2024
% purpose: to 1) generate speed profiles for the C3 study, which requires
% the experimenter to manually input the participant ID, speeds, and slow
% leg at the top of this script, 2) automate the experimental flow by
% choosing the correct order of the conditions / trials and the correct
% controllers and profiles.

%% Retrieve Participant Data from Experimenter
prompt = { ...
    ['Enter the participant ID (''C3S##'' for participants with ' ...
    'stroke, ''C3C##'' for control participants, do NOT include ' ...
    '''_S#'' for the session):'], ...
    'Is this session 1? (''1'' = true, ''0'' = false)'};
dlgtitle = 'Participant Experimental Inputs';
fieldsize = [1 60; 1 60];
definput = {'Test', ...                     participant ID
    '1'};                                   % is session 1
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

% Extract Participant Experimental Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% comment out the above GUI block, and manually enter the desired values
% below (e.g., participantID = 'Test';) if preferred
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ID: C3S## for participants with stroke, C3C## for control participants
% NOTE: do NOT include '_S1' or '_S2' here to indicate session
participantID = answer{1};
isSession1 = logical(str2double(answer{2}));% is first session?
% date threshold for copying recent files in datlogs
threshTime = datetime('now','InputFormat','dd-MMM-yyyy HH:mm:ss');
isCtrl = startsWith(participantID,'C3C');

%% Retrieve 6-Minute/10-Meter Walk Test Data Input from Experimenter
if isSession1 && ~isCtrl    % if session 1 and not control participant, ...
    % 6MWT/10MWT is only completed during session 1
    [speedOGMid,speedOGFast] = utils.extractSpeedsNMWT();
end

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
raw = dir(fullfile(dirBase,participantID)); % retrieve folder
ignore = endsWith({raw.name},{'.','..'});   % remove current/parent
profiles = raw(~ignore);
if isSession1                               % if session 1, ...
    % Request User Input for Speed Profile Generation
    opts.Interpreter = 'none';
    opts.Default = 'No, I generated them already';
    shouldGenProfiles = questdlg(['Regenerate profiles? Confirm ' ...
        'participant ID and other inputs are correct in ' ...
        'RunProtocol_C3.m.'], ...
        'Regenerate Profiles?','Yes','No, I generated them already',opts);
    switch shouldGenProfiles
        case 'Yes'
            % generate speed profiles for both legs as slow leg since
            % decide later which leg will be fast/slow based on step length
            dirProfileR = generateProfiles_C3(participantID,'R', ...
                speedOGMid,speedOGFast);
            dirProfileL = generateProfiles_C3(participantID,'L', ...
                speedOGMid,speedOGFast);
            dirProfile = dirProfileR;
        case 'No, I generated them already'
            if isempty(profiles)
                disp(['There are no profiles found, quitting the ' ...
                    'script now.']);
                return;
            else
                disp(['The profiles are already generated, continuing ' ...
                    'with the experiment.']);
                dirProfile = fullfile(dirBase,participantID, ...
                    profiles(1).name);
            end
        otherwise
            disp('No response was provided, quitting the script now.');
            return;
    end
    % display slow, fast, and middle speeds for experimenter documentation
    load(fullfile(dirProfile,'TM_Adaptation.mat'));
    fprintf('The slow treadmill speed is %.3f m/s.\n',velR(1));
    fprintf('The fast treadmill speed is %.3f m/s.\n',velL(1));
    load(fullfile(dirProfile,'TM_Baseline_Mid1.mat'));
    fprintf('The mid treadmill speed is %.3f m/s.\n',velR(1));
else                                            % otherwise, session 2
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
            % TODO: implement automatically running SLRealTime script
            if isSession1                       % if first session, ...
                answer = questdlg(['Now run the ''SLRealtime'' Vicon ' ...
                    'Nexus processing script on the TM_Baseline_Mid1 ' ...
                    'trial. Which leg has the *longer* step length ' ...
                    '(i.e., which leg should be on the slow belt)?'], ...
                    'Which leg is slow?','Right','Left','Cancel','Right');
                switch answer
                    case 'Right'
                        dirProfile = dirProfileR;
                        % TODO: output status to ensure deletion occurs
                        rmdir(dirProfileL,'s'); % delete unused profiles
                    case 'Left'
                        dirProfile = dirProfileL;
                        rmdir(dirProfileR,'s');
                    case 'Cancel'
                        return;                 % terminate experiment
                end
            end
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
        case {7,8,9,10,11,12}   % TM Adaptation (Split)
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Adaptation.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open Loop ' ...
                'Controller with Audio Countdown and profile is ' ...
                'TM_Adaptation']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            if currTrial == 9               % if trial 9, ...
                pause(pauseTime3min20sec);  % need more time for BP/HR
            elseif currTrial == 12          % if trial 12, ...
                pause(pauseTime1min);       % short before post-adaptation
            else                            % otherwise, ...
                pause(pauseTime2min);       % default to two minutes
            end
            play(AudioTimeUp);
        case {13,14,15}                     % Post-Adaptation 1
            if isSession1                   % if session 1, ...
                handles.popupmenu2.set('Value',8);  % OG
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is Overground ' ...
                    'audio speed feedback and profile is PostAdaptation']);
            elseif ~isSession1              % if session 2, ...
                handles.popupmenu2.set('Value',11); % TM
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is Open Loop ' ...
                    'Controller with Audio Countdown and profile is ' ...
                    'PostAdaptation']);
                numAudioCountDown = -1;
            else                                    % otherwise, ...
                % TODO: implement error handling
            end
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            if currTrial == 15              % if trial 15, ...
                pause(pauseTime3min20sec);  % need more time for BP/HR
            else                            % otherwise, ...
                pause(pauseTime2min);       % default to two minutes
            end
            play(AudioTimeUp);
        case {16,17}    % Post-Adaptation 2
            if isSession1                   % if session 1, ...
                handles.popupmenu2.set('Value',11);  % TM
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is Open Loop ' ...
                    'Controller with Audio Countdown and profile is ' ...
                    'PostAdaptation']);
                numAudioCountDown = -1;
            elseif ~isSession1              % if session 2, ...
                handles.popupmenu2.set('Value',8); % OG
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is Overground ' ...
                    'audio speed feedback and profile is PostAdaptation']);
            else                                    % otherwise, ...
                % TODO: implement error handling
            end
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            if currTrial == 16              % if trial 16, ...
                % do not care about break after last walking trial
                pause(pauseTime2min);
                play(AudioTimeUp);
            end
    end
end

%% Transfer the Data After the Experiment Has Finished
% pause for one minute to allow Vicon Nexus to stop and save last trial
pause(60);
tic;
transferData_PC1_C3(participantID,isSession1,threshTime);
toc;

%% Run Reconstruct & Label Pipeline & Automatically Fill Small Marker Gaps
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ONLY RUN THIS BLOCK ON THE LAB PC1 IF THERE IS SUFFICIENT TIME BEFORE THE
% NEXT EXPERIMENTER NEEDS THE LAB SPACE
% Duration: ~46 minutes for 17 trials (entire session)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;
sess = 'Session1';
if ~isSession1          % if current session is second walking session, ...
    sess = 'Session2';
end
dirSrvrData = fullfile('W:\Nathan\C3\Data',participantID,sess,'PC1');
dataMotion.processAndFillMarkerGapsSession(dirSrvrData);
toc;

