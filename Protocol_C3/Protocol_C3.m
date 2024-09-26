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
        generateProfile_C3(participantID,'R',speedOGMid,speedOGFast);
        generateProfile_C3(participantID,'L',speedOGMid,speedOGFast);
    case 'No, I generated them already'
        disp(['The profiles are already generated, continuing with the' ...
            ' experiment.']);
    otherwise
        disp('No response was provided, quitting the script now.');
        return;
end

%% Set Up GUI & Run the Experiment
% load audio for break time up.
[audio_data,audio_fs] = audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

% load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

maxCond = 17;
pauseTime2min30 = 115; %2.5min, with the vicon stop/start timing ends up about 2.5mins
pauseTime1min = 40;
% pauseTime5m = 265; %4.5min,with the vicon stop/start timing ends up about 5mins

%% start the protocol
%the TM will start now/ stop now is not exacttly on point but maybe not
%easy to make it better.
isCalibration = false; %reset iscalib to false.
firstCond = true;
currCond = 0; %default value to start while loop.
while currCond < maxCond
    if ~firstCond
        nextCondButton=questdlg('Auto continue with next condition?');
        if strcmp(nextCondButton,'Yes') %automatically advance to next condition.
            currCond = currCond + 1;
            if contains(participantID,'SAH') && ismember(currCond,[3,4]) %Healthy young people & OG trials now
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
            profilename = [dirProfile, 'TMBaseFast.mat'];
            manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm controller is Nirs, Hreflex, Open loop controller with audio countdown and profile is TMBaseFast');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 2 %TM base slow
            handles.popupmenu2.set('Value',14) %Nirs, Hreflex, OPEN Loop with count down.
            profilename = [dirProfile, 'TMBaseSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm controller is Nirs, Hreflex, Open loop controller with audio countdown and profile is TMBaseSlow');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {3} %OG Fast
            handles.popupmenu2.set('Value',16) %OG Audio with HreflexOGWithAudio
            profilename = [dirProfile 'OGBaseFast.mat'];
            manualLoadProfile([],[],handles,profilename)
            %now will ask user to change the speed info.
            answer=questdlg('Confirm controller is HreflexOGWithAudio and speed profile is fast');
            if ~strcmp(answer,'Yes')
                return; %Always return and quit because now needs experimenter change in OG controller for the next 3 trials.
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {4} %OG Slow
            handles.popupmenu2.set('Value',16) %OG Audio with Hreflex
            profilename = [dirProfile 'OGBaseSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            %now will ask user to change the speed info.
            answer=questdlg('Confirm controller is HreflexOGWithAudio and speed profile is slow');
            if ~strcmp(answer,'Yes')
                return; %Always return and quit because now needs experimenter change in OG controller for the next 3 trials.
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {5,6} %pre train
            handles.popupmenu2.set('Value',14) %NIRS train
            if currCond == 5 %1st pre train
                profilename = [dirProfile 'PreSplitTrain_1.mat'];
            else
                profilename = [dirProfile 'PreSplitTrain_2.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Please confirm the trial information: Nirs Train Pre?');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime2min30); %break for 5mins at least.
            play(AudioTimeUp);
        case {12,13} %post nirs train
            handles.popupmenu2.set('Value',14) %NIRS train
            if currCond == 12 %1st post train
                profilename = [dirProfile 'PostSplitTrain_1.mat'];
            else
                profilename = [dirProfile 'PostSplitTrain_2.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Please confirm the trial information: Nirs Train Post?');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            %             if currCond == 12 %only time break for 1st train.
            pause(pauseTime2min30); %break for 5mins at least.
            play(AudioTimeUp);
            %             end
        case {7,8,9,10,11} %1st adapt
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [dirProfile 'Adapt.mat'];
            manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm trial and profile is Adapt');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime2min30); %~2.5mins
            play(AudioTimeUp);
        case 14 %post 1
            handles.popupmenu2.set('Value',14) %open loop with countdown with NIRS
            profilename = [dirProfile 'Post1.mat'];manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm trial and profile is Post-Adapt 200 strides');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime1min); %~2.5mins
            play(AudioTimeUp);
        case 15 %post 2
            handles.popupmenu2.set('Value',14) %NIRS open loop with countdown
            profilename = [dirProfile 'Post2.mat'];manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm trial and profile is Post-Adapt 100 strides with rest');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime1min); %~2.5mins
            play(AudioTimeUp);
        case 16 %neg short first
            handles.popupmenu2.set('Value',11) %open loop with countdown
            profilename = [dirProfile 'NegShort.mat'];manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm trial and profile is NegShort');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [50 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(pauseTime1min); %~2.5mins
            play(AudioTimeUp);
        case 17 %then pos short
            handles.popupmenu2.set('Value',11) %open loop with countdown
            profilename = [dirProfile 'PosShort.mat'];manualLoadProfile([],[],handles,profilename)
            answer=questdlg('Confirm trial and profile is PosShort');
            if ~strcmp(answer,'Yes')
                return; %Abort starting the exp
            end
            numAudioCountDown = [100 130 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
    end
end
