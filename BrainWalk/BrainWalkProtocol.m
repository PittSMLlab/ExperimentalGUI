%% This script run the Brain walk protocol behavior portion.

%% 1. set up which session to run and dominant leg for each participant
visitOptions = {'Visit2(Pre)','Visit3(Practice)','Visit4(Post TM + Nirs Alphabet)','Visit5(Nirs N-back)'};
[visitNum,~] = listdlg('PromptString','What visit is this?','ListString',visitOptions,'SelectionMode','single','ListSize',[200,100]);
if isempty(visitNum)
    error('Invalid selection. Try again.')
else
    confirmVisit = questdlg(sprintf('You selected: %s.\n Is this correct?',visitOptions{visitNum}));
    if ~strcmp(confirmVisit,'Yes')
        error('Invalid selection. Try again.')%Abort starting the trial
    end
end

opts.Interpreter = 'tex';
opts.Default = 'Right';
dominantRight = questdlg(['Dominant leg is: '],'', ...
    'Left','Right',opts);
if strcmp(dominantRight,'Right')
    dominantRight = true;
else
    dominantRight = false;
end

%display the selections
visitNum = visitOptions{visitNum}
dominantRight

%% Set up GUI and run exp
%load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

[audio_data,audio_fs]=audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

if ismember(visitNum,{'Visit2(Pre)','Visit3(Practice)','Visit4(Post TM)'})
    TMprotocolComplete = false;
    breakTime = 170; %a little over 3mins
else
    TMprotocolComplete = true; %not a TM trial, skip the next section
end

%% Starr the protocol
currCond = 0;

while ~TMprotocolComplete
    if currCond == 0
        button=questdlg('Start with the first condition?');
    else
        button=questdlg('Advance to next condition?');
    end
    if strcmp(button,'Yes') %automatically advance to next condition.
        currCond = currCond + 1;
    else 
        %manually chose conditions
        currCond = inputdlg('What is the condition number you want to run(1st column on the datasheet): ');
        currCond = str2num(currCond{1});
    end
    
    if strcmpi(visitNum,'Visit2(Pre)')
        %% Pre, visit 2
        switch currCond
            case {1,8,9} %OG trials w/o audio feedback
                handles.popupmenu2.set('Value',8) %OG Audio
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\OGTrials.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Please confirm the trial information: OG trial?'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                if ismember(currCond, [8,9]) %OGPost
                    pause(breakTime); 
                    play(AudioTimeUp);
                end
            case 2 %tmbase fast
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\TMBaselineFast.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 50 strides with 1m/s (TMBaselineFast)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            case 3 %TMBaselineSlow
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\TMBaselineSlow.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 50 strides with 0.5 m/s (TMBaselineSlow)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
            case 4 %mid then adapt
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\MidBaseAndAdaptation_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\MidBaseAndAdaptation_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 150 strides with 0.75m/s, then R at 1m/s and L at 0.5m/s for 150 strides (MidBaseAndAdaptation_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 150 strides with 0.75m/s, then L at 1m/s and R at 0.5m/s for 150 strides (MidBaseAndAdaptation_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [150 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
            case {5,6} %adaptation
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\Adaptation_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\Adaptation_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 300 strides with R at 1m/s and L at 0.5m/s (Adaptation_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 300 strides with L at 1m/s and R at 0.5m/s (Adaptation_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
            case 7 %adaptation last 150
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\Adaptation_150strides_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\Adaptation_150strides_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 150 strides with R at 1m/s and L at 0.5m/s (Adaptation_150strides_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 150 strides with L at 1m/s and R at 0.5m/s (Adaptation_150strides_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)      
            case 10 %TMPost
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\TMMidPost.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 300 strides with 0.75m/s (TMMidPost)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime);
                play(AudioTimeUp);            
            case 11 %neg short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\NegShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\NegShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then 25 strides at 0.75m/s both leg (NegShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then 25 strides at 0.75m/s both leg (NegShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 80 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
            case 12 %pos short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\PosShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Pre\PosShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then 25 strides at 0.75m/s both leg (PosShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then 25 strides at 0.75m/s both leg (PosShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 80 -1];%set the stride to give the count down at last stride of the previous speed config
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                TMprotocolComplete = true;
        end %end of switch statement for visit02
   
    elseif strcmpi(visitNum,'Visit3(Practice)')
        %% visit 3
        switch currCond 
            case 1 %tm base fast
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\TMBaselineFast.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 50 strides with 1m/s (TMBaselineFast)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
            case 2 %tmbase slow
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\TMBaselineSlow.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 50 strides with 0.5m/s (TMBaselineSlow)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp); 
           case 3 %tmbase mid
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\TMBaselineMid300.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 300 strides with 0.75m/s (TMBaselineMid300)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp); 
            case 4 %adaptation 1
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\Adaptation1_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\Adaptation1_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides with 0.75m/s, then R at 1m/s and L at 0.5m/s for 200 strides, then 25 strides with 0.75m/s (Adaptation1_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides with 0.75m/s, then L at 1m/s and R at 0.5m/s for 200 strides, then 25 strides with 0.75m/s (Adaptation1_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 250 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
            case {5,6,7} %adaptation 2-4
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\Adaptation2-4_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\Adaptation2-4_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 25 strides with 0.75m/s, then R at 1m/s and L at 0.5m/s for 200 strides, then 25 strides with 0.75m/s (Adaptation2-4_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 25 strides with 0.75m/s, then L at 1m/s and R at 0.5m/s for 200 strides, then 25 strides with 0.75m/s (Adaptation2-4_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [25 225 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);            
            case 8 %adaptation5 wiith a tied end
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\Adaptation5_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\Adaptation5_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 25 strides at 0.75m/s, then 200 strides with R at 1m/s and L at 0.5m/s, then 50 strides at 0.75m/s (Adaptation5_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 25 strides at 0.75m/s, then 200 strides with L at 1m/s and R at 0.5m/s, then 50 strides at 0.75m/s (Adaptation5_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [25 225 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);  
           case 9 %TMPost
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\TMPostMid250.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 250 strides with 0.75m/s (TMPostMid250)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);            
            case 10 %neg short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\NegShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\NegShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then 25 strides at 0.75m/s both leg (NegShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then 25 strides at 0.75m/s both leg (NegShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 80 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
            case 11 %pos short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\PosShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Practice\PosShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then 25 strides at 0.75m/s both leg (PosShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then 25 strides at 0.75m/s both leg (PosShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 80 -1];%set the stride to give the count down at last stride of the previous speed config
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                TMprotocolComplete = true;
        end %end of switch statement for v03
    
    elseif strcmpi(visitNum,'Visit4(Post TM + Nirs Alphabet)')
        %% visit 4
        switch currCond
            case 1 %tmbase fast
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\TMBaselineFast.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 50 strides with 1m/s (TMBaselineFast)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            case 2 %TMBaselineSlow
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\TMBaselineSlow.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 50 strides with 0.5 m/s (TMBaselineSlow)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
            case 3 %TMBaseline Mid
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\TMBaselineMid300.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 300 strides with 0.75 m/s (TMBaselineMid300)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
            case 4 %mid then adapt then post
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\MidBaseAndAdaptationAndPost_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\MidBaseAndAdaptationAndPost_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides with 0.75m/s, then R at 1m/s and L at 0.5m/s for 150 strides, then tied 0.75m/s for 50 strides (MidBaseAndAdaptationAndPost_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides with 0.75m/s, then L at 1m/s and R at 0.5m/s for 150 strides, then tied 0.75m/s for 50 strides (MidBaseAndAdaptationAndPost_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 200 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); 
                play(AudioTimeUp);
           case 5 %TMPost
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\TMMid100.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 100 strides with 0.75m/s (TMMid100)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime);
                play(AudioTimeUp);            
            case 6 %neg short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\NegShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\NegShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then 25 strides at 0.75m/s both leg (NegShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then 25 strides at 0.75m/s both leg (NegShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 80 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
            case 7 %pos short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\PosShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Post\PosShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then 25 strides at 0.75m/s both leg (PosShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then 25 strides at 0.75m/s both leg (PosShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 80 -1];%set the stride to give the count down at last stride of the previous speed config
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                TMprotocolComplete = true;
        end %end of switch for visit 3
        
    end %end of the if else loop per visit
end %end of big while loop


%% Now run DT
if strcmpi(visitNum,'Visit4(Post TM + Nirs Alphabet)')
    protocolComplete = false; %start with -1 first prompt will advance you to 0

    while ~protocolComplete
        handles.popupmenu2.set('Value',10) %AutomaticityAssessmentProtocol
        profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\AlphabetTrials.mat';
        manualLoadProfile([],[],handles,profilename)
        AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        %Can not by pass the trial selection and do auto-advance because
        %need to call the adaptation GUI, and will have to go through
        %everything in the switch statement in AdaptationGUI.
        %If by passthat and call NirsAutomaticityAssessment fucntion
        %directly, will loose the control to auto start/stop Vicon, and
        %interact with GUI to stop the trial.
        
        %confirm do you want to keep going?
        button=questdlg('Keep running NirsAutomaticityAssessment (alphabet dual-task) trials? (Choose No No if all trials are done)');
        if ~strcmp(button,'Yes') %confirm trial choice is correct
          protocolComplete = true; %If chose no, abort starting the exp
        end
    end  
end

%% Now run optional DT for N-back
if strcmpi(visitNum, 'Visit5(Nirs N-back)')
    protocolComplete = false; %start with -1 first prompt will advance you to 0
    confirmProfile = false;
    while ~protocolComplete
        handles.popupmenu2.set('Value',13) %AutomaticityAssessmentProtocol
        profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\OGNbackTrials.mat';
        manualLoadProfile([],[],handles,profilename)
        AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        %Can not by pass the trial selection and do auto-advance because
        %need to call the adaptation GUI, and will have to go through
        %everything in the switch statement in AdaptationGUI.
        %If by passthat and call NirsAutomaticityAssessment fucntion
        %directly, will loose the control to auto start/stop Vicon, and
        %interact with GUI to stop the trial.
        
        %confirm do you want to keep going?
        button=questdlg('Keep running NirsAutomaticityAssessment (OG N-back) trials? (Choose No if all trials are done)');
        if ~strcmp(button,'Yes') %confirm trial choice is correct
          protocolComplete = true; %If chose no, abort starting the exp
        end
    end  
end

%% Now transfer the data
transferDataAndSaveC3D_BrainWalk()

%% Logic to auto advance for alphabet task
% if currCond == -1
%     button=questdlg('Start with the familiarization?');
%     if strcmp(button,'Yes') %automatically advance to next condition.
%         currCond = currCond + 1;
%     else 
%         %manually chose conditions
%         currCond = inputdlg('What is the trial number you want to run(0 for familiarization, 1-6 for trial1-6): ');
%         currCond = str2num(currCond{1});
%     end 
% else
%     opts.Interpreter = 'tex';
%     opts.Default = 'Advance';
%     dominantRight = questdlg(['Advance to next trial? '],'', ...
%         'Advance','Repeat Current Trial','Choose Something Else',opts);
%     if strcmp(dominantRight,'Advance')
%         currCond = currCond + 1;
%     elseif strcmp(dominantRight,'Choose Something Else')
%         %manually chose conditions
%         currCond = inputdlg('What is the trial number you want to run(0 for familiarization, 1-6 for trial1-6): ');
%         currCond = str2num(currCond{1});
%     end%otherwise stay and repeat
% end
% 
% if currCond == 0
%     condName = 'Familiarization';
% else
%     condName = ['Trial ' num2str(currCond)];
% end
