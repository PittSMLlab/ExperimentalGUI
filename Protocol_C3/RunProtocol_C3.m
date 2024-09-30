% author: NWB
% date (created): 04 Sep. 2024
% purpose: to 1) generate speed profiles for the C3 study, which requires
% the experimenter to manually update the participant ID, speeds, and fast
% leg at the top of this script, 2) automate the experimental flow by
% choosing the correct order of the conditions / trials and the correct
% controllers and profiles.

% TODO:
%   - add more details regarding the conditions for this experiment to the
%   comment block above

%% Retrieve Participant Data from Experimenter
prompt = { ...
    ['Enter the participant ID (''C3S##'' for participants with ' ...
    'stroke, ''C3C##'' for control participants, do NOT include ' ...
    '''_S#'' for the session):'], ...
    'Is this participant in Group 1? (''1'' = true, ''0'' = false)', ...
    'Is this session 1? (''1'' = true, ''0'' = false)'};
dlgtitle = 'Participant Experimental Inputs';
fieldsize = [1 60; 1 60; 1 60];
definput = {'Test', ...                     participant ID
    '1', ...                                is group 1
    '1'};                                   % is session 1
answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

%% Extract Participant Experimental Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% if you do not like the MATLAB GUI to receive experimental inputs as
% above, comment out the above block and manually enter the desired values
% for each of the three variables here (e.g., participantID = 'Test';).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ID: C3S## for participants with stroke, C3C## for control participants
% NOTE: do NOT include '_S1' or '_S2' here to indicate session
participantID = answer{1};
isGroup1 = logical(str2double(answer{2}));  % is first experimental group?
isSession1 = logical(str2double(answer{3}));% is first session?

%% 6-Minute/10-Meter Walk Test Data Input
if isSession1                               % if session 1, ...
    % Retrieve 6-Minute/10-Meter Walk Test Data from Experimenter
    prompt = { ...
        ['Enter the list of 10-Meter walk times (in seconds) you ' ...
        'would like to average to compute the fast overground walking' ...
        ' speed:'], ...
        'How many 6-Minute Walk Test laps should be computed?', ...
        'What is the tape measure distance (in inches)?', ...
        ['Should the additional distance be added to the laps above? ' ...
        '(as opposed to being subtracted, ''1'' = true, ''0'' = false)']};
    dlgtitle = '6MWT/10MWT Experimental Inputs';
    fieldsize = [1 125; 1 125; 1 125; 1 125];
    definput = { ...                        10MWT times (in seconds) list
        '7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00', ...
        '30', ...                           number of 6MWT laps
        '0', ...                            tape measure distance (inches)
        '1'};                               % should add above distance?
    answer = inputdlg(prompt,dlgtitle,fieldsize,definput);

    % Extract 6MWT/10MWT Experimental Parameters
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % if you do not like the MATLAB GUI to receive experimental inputs as
    % above, comment out the above block and manually enter the desired
    % values for each of the four variables here.
    % e.g., times_10MWT = [7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    times_10MWT = strsplit(answer{1},' ');      % list 10MWT times (secs)
    numLaps_6MWT = str2double(answer{2});       % number of 6MWT laps
    distInches_6MWT = str2double(answer{3});    % measure distance (inches)
    shouldAdd = logical(str2double(answer{4})); % should + or - distance?

    % Compute 6MWT/10MWT Speeds
    speedOGFast = 10 / mean(times_10MWT);   % fast OG walking speed - 10MWT
    if shouldAdd                            % if should add distance, ...
        % compute 6MWT distance as sum of # of laps times walkway distance
        % (~12.2 meters) + remainder distance in inches converted to meters
        dist_6MWT = (numLaps_6MWT * 12.2) + (distInches_6MWT * 0.0254);
    else                                    % otherwise, subtract distance
        dist_6MWT = (numLaps_6MWT * 12.2) - (distInches_6MWT * 0.0254);
    end
    % 360 seconds is 6 minutes
    speedOGMid = dist_6MWT / 360;           % comfortable 6MWT OG speed

    % Request User Input for Speed Profile Generation
    opts.Interpreter = 'none';
    opts.Default = 'No, I generated them already';
    shouldGenProfiles = questdlg(['Regenerate profiles? Confirm ' ...
        'participant ID and other inputs are correct in ' ...
        'RunProtocol_C3.m.'], ...
        'Regenerate Profiles?','Yes','No, I generated them already',opts);
    switch shouldGenProfiles
        case 'Yes'
            % generate speed profiles for both legs as slow leg since decide
            % later which leg will be fast/slow based on step length
            dirProfileR = generateProfiles_C3(participantID,'R', ...
                speedOGMid,speedOGFast);
            dirProfileL = generateProfiles_C3(participantID,'L', ...
                speedOGMid,speedOGFast);
        case 'No, I generated them already'
            disp(['The profiles are already generated, continuing with the' ...
                ' experiment.']);
        otherwise
            disp('No response was provided, quitting the script now.');
            return;
    end
    dirProfile = dirProfileR;
else                                            % otherwise, session 2
    dirBase = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\' ...
        'profiles\Stroke_CCC'];
    % TODO: test that below code works as desired
    raw = dir(fullfile(dirBase,participantID)); % retrieve folder
    ignore = endsWith({raw.name},{'.','..'});   % remove current/parent
    % NOTE: there should only be one profile folder since the irrelevant
    % one should have been deleted in session 1
    profiles = raw(~ignore);
    dirProfile = fullfile(dirBase,participantID,profiles.name);
end

%% Set Up the GUI & Run the Experiment
% load audio file for announcing the end of the break
[audio_data,audio_fs] = audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

% load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

maxTrials = 17;         % maximum number of trials
% TODO: update below parameters to reflect C3 experiment
pauseTime2min30 = 115; %2.5min, with the vicon stop/start timing ends up about 2.5mins
pauseTime1min = 40;
% pauseTime5m = 265; %4.5min,with the vicon stop/start timing ends up about 5mins

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

    switch currTrial
        case 1          % TM Baseline Mid (Tied)
            % open-loop controller with audio count down
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Baseline_Mid1.mat');
            manualLoadProfile([],[],handles,profilename);
            % TODO: update dialog prompts with exact name match
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_Baseline_Mid1']);
            if ~strcmp(answer,'Yes')% if incorrect controller/profile, ...
                return;             % abort starting experiment
            end
            numAudioCountDown = -1; % include final audio countdown
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles)
            % No fixed break here - proceed immediately in GUI
        case 2          % TM Baseline Fast (Tied)
            handles.popupmenu2.set('Value',11);
            profilename = fullile(dirProfile,'TM_Baseline_Fast.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_Baseline_Fast']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % No fixed break here - proceed immediately in GUI
        case 3          % OG Baseline Mid
            % overground controller with audio count down
            handles.popupmenu2.set('Value',8);
            profilename = fullfile(dirProfile,'OG_Baseline_Mid.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is overground ' ...
                'controller with audio feedback and profile is ' ...
                'OG_Baseline_Mid']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % TODO: implement automatically running SLRealTime script
            if isSession1                       % if first session, ...
                answer = questdlg(['Now run the ''SLRealtime'' Vicon ' ...
                    'Nexus processing script on the TM Baseline Mid ' ...
                    'trial. Which leg has the *longer* step length ' ...
                    '(i.e., which leg should be on the slow belt)?'], ...
                    'Which leg is slow?','Right','Left','Cancel','Right');
                switch answer
                    case 'Right'
                        dirProfile = dirProfileR;
                        % TODO: output status to ensure deletion occurs
                        rmdir(dirProfileL);     % delete unused profiles
                    case 'Left'
                        dirProfile = dirProfileL;
                        rmdir(dirProfileR);
                    case 'Cancel'
                        return;                 % terminate experiment
                end
            end
        case 4          % TM Short Exposure Negative
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_ShortExposure_Neg.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_ShortExposure_Neg']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = [50 100 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % TODO: implement fixed break here
        case 5          % TM Short Exposure Positive
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_ShortExposure_Pos.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_ShortExposure_Pos']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = [50 100 -1];
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles)
            % TODO: implement fixed break here
            % pause(pauseTime2min30); %break for 5mins at least.
            % play(AudioTimeUp);
        case 6          % TM Baseline Mid Full (Tied)
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Baseline_Mid2.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_Baseline_Mid2']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % TODO: implement fixed break here
            % pause(pauseTime2min30); %break for 5mins at least.
            % play(AudioTimeUp);
        case {7,8,9,10,11,12}   % TM Adaptation (Split)
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'TM_Adaptation.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_Baseline_Mid2']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % TODO: handle different break durations depending on trial
            % trial 9 has longer break for BP, trial 12 has short break
            % pause(pauseTime2min30); %~2.5mins
            % play(AudioTimeUp);
        case {13,14,15} % Post-Adaptation 1
            % if group 1, session 1 or group 2, session 2, ...
            if (isGroup1 && isSession1) || (~isGroup1 && ~isSession1)
                handles.popupmenu2.set('Value',8);  % OG
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is overground ' ...
                    'controller with audio feedback and profile is ' ...
                    'PostAdaptation']);
                % if group 1, session 2 or group 2, session 1, ...
            elseif (isGroup1 && ~isSession1) || (~isGroup1 && isSession1)
                handles.popupmenu2.set('Value',11); % TM
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is open loop ' ...
                    'controller with audio countdown and profile is ' ...
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
            % pause(pauseTime1min); %~2.5mins
            % play(AudioTimeUp);
        case {16,17}    % Post-Adaptation 2
            % if group 1, session 1 or group 2, session 2, ...
            if (isGroup1 && isSession1) || (~isGroup1 && ~isSession1)
                handles.popupmenu2.set('Value',11);  % TM
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is open loop ' ...
                    'controller with audio countdown and profile is ' ...
                    'PostAdaptation']);
                numAudioCountDown = -1;
                % if group 1, session 2 or group 2, session 1, ...
            elseif (isGroup1 && ~isSession1) || (~isGroup1 && isSession1)
                handles.popupmenu2.set('Value',8); % OG
                profilename = fullfile(dirProfile,'PostAdaptation.mat');
                manualLoadProfile([],[],handles,profilename);
                answer = questdlg(['Confirm controller is overground ' ...
                    'controller with audio feedback and profile is ' ...
                    'PostAdaptation']);
            else                                    % otherwise, ...
                % TODO: implement error handling
            end
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % pause(pauseTime1min); %~2.5mins
            % play(AudioTimeUp);
    end
end

