% author: NWB
% date (created): 04 Sep. 2024
% purpose: to 1) generate speed profiles for the C3 study, which requires
% the experimenter to manually update the participant ID, speeds, and fast
% leg at the top of this script, 2) automate the experimental flow by
% choosing the correct order of the conditions / trials and the correct
% controllers and profiles.

% TODO:
%   - add feature to open a GUI to request fast leg from participant after
%   baseline walking trials
%   - prompt experimenter to run SL MATLAB script or automatically initiate
%   via ViconSDK
%   - delete unused profiles after determining slow/fast leg
%   - for session 2 retrieve all previously used profiles
%   - add more details regarding the conditions for this experiment to the
%   comment block above
%   - create GUI to accept initial experimenter inputs from 6MWT/10MWT
%   - do not recreate profiles or request any 6MWT/10MWT data if session 2

%% Experimental Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% EXPERIMENTER MUST UPDATE BELOW PARAMETERS BEFORE EACH EXPERIMENT %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ID: C3S## for participants with stroke, C3C## for control participants
% NOTE: do NOT include '_S1' or '_S2' here to indicate session
participantID = 'Test';
isSession1 = true;                      % is current session first session?
times_10MWT = [7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00 7.00];
numLaps_6MWT = 30;                      % number of 6MWT laps
distInches_6MWT = 0;                    % distance (inches) measured at end
shouldAdd = true;                       % should add or subtract distance?
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

speedOGFast = 10 / mean(times_10MWT);   % fast OG walking speed - 10MWT
if shouldAdd                            % if should add extra distance, ...
    % compute 6MWT distance as sum of number of laps times walkway distance
    % (~12.2 meters) plus remainder distance in inches converted to meters
    dist_6MWT = (numLaps_6MWT * 12.2) + (distInches_6MWT * 0.0254);
else                                    % otherwise, subtract distance
    dist_6MWT = (numLaps_6MWT * 12.2) - (distInches_6MWT * 0.0254);
end
% 360 seconds is 6 minutes
speedOGMid = dist_6MWT / 360;           % comfortable OG walking speed 6MWT

%% Request User Input Regarding Profile Generation
% answer = 'Yes';     % default to 'yes' don't check it
% if contains(participantID,'_S2')    % if second walking session, ...
%     answer = questdlg(['The fast leg should be identical to that of ' ...
%         'session 1. Was the fast leg ' legFast '?']);
% end
% if ~strcmp(answer,'Yes')
%     return; % abort starting until experimenter fixes fast leg assignment
% end

opts.Interpreter = 'tex';
opts.Default = 'No, I generated them already';
shouldGenProfiles = questdlg(['Regenerate profiles? Confirm ' ...
    'participant ID and other inputs are correct in RunProtocol_C3.m.'],...
    'RegenProfile','Yes','No, I generated them already',opts);
switch shouldGenProfiles
    case 'Yes'
        % % confirm again the fast leg is correct
        % answer = questdlg(['Just to double check: now create profile ' ...
        %     'where the fast leg is ' legFast '. Is that correct?']);
        % if ~strcmp(answer,'Yes')
        %     return; % abort starting the session
        % end
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
            % TODO: handle case of session 2 possibly different profile dir
            profilename = fullfile(dirProfileR,'TM_Baseline_Mid1.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_Baseline_Mid1']);
            if ~strcmp(answer,'Yes')% if incorrect controller/profile, ...
                return;             % abort starting experiment
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles)
        case 2          % TM Baseline Fast (Tied)
            handles.popupmenu2.set('Value',11);
            profilename = fullile(dirProfileR,'TM_Baseline_Fast.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is Open loop ' ...
                'controller with audio countdown and profile is ' ...
                'TM_Baseline_Fast']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
        case 3          % OG Baseline Mid
            % overground controller with audio count down
            handles.popupmenu2.set('Value',8);
            profilename = fullfile(dirProfileR,'OG_Baseline_Mid.mat');
            manualLoadProfile([],[],handles,profilename);
            answer = questdlg(['Confirm controller is overground ' ...
                'controller with audio feedback and profile is ' ...
                'OG_Baseline_Mid']);
            if ~strcmp(answer,'Yes')
                return;
            end
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % TODO: after this trial is when the SL script must be run
            % during session 1
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
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
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
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles)
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
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
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
            % pause(pauseTime2min30); %~2.5mins
            % play(AudioTimeUp);
        case {13,14,15} % Post-Adaptation 1
            % TODO: handle group 1/2, session 1/2 behavior
            handles.popupmenu2.set('Value',11); % OR '8' if OG
            profilename = fullfile(dirProfile,'PostAdaptation.mat');
            manualLoadProfile([],[],handles,profilename);
            % TODO: different prompt depending on group/session
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'PostAdaptation']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % pause(pauseTime1min); %~2.5mins
            % play(AudioTimeUp);
        case {16,17}    % Post-Adaptation 2
            handles.popupmenu2.set('Value',11);
            profilename = fullfile(dirProfile,'PostAdaptation.mat');
            manualLoadProfile([],[],handles,profilename);
            % TODO:
            answer = questdlg(['Confirm controller is open loop ' ...
                'controller with audio countdown and profile is ' ...
                'PostAdaptation']);
            if ~strcmp(answer,'Yes')
                return;
            end
            numAudioCountDown = -1;
            AdaptationGUI('Execute_button_Callback', ...
                handles.Execute_button,[],handles);
            % pause(pauseTime1min); %~2.5mins
            % play(AudioTimeUp);
    end
end

