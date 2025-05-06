%% set up trial condition and dominant leg for each participant
StudyID = 'BW'; %change this manually if it's AUF or MAU
opts.Interpreter = 'tex';
opts.Default = '1';
visitNum = questdlg('What visit is this?','', ...
    '2(Pre)','3(Practice)','4(Post/DT)',opts);

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
visitNum
dominantRight
% intervention = true; %true for visit 3, false for visit 2 and 4
% % AUC: false for visits 1 and 3, true for visit 2
% dominantRight = true; %true if right dominant, false if left dominant

%% Set up GUI and run exp
%load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

[audio_data,audio_fs]=audioread('TimeToWalk.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

protocolComplete = false;
breakTime = 170; %a little over 3mins

%% Starr the protocol
currCond = 0;

while ~protocolComplete
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

    if strcmpi(visitNum,'2(Pre)')
        %% pre-post intervention
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
                pause(breakTime); %2.5mins
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
                protocolComplete = true;
        end %end of switch statement for visit02

    
    elseif strcmpi(visitNum,'3(Practice)')
        %%
        switch currCond
            case {1,9,10,13,15} %OG trials w/o audio feedback
                handles.popupmenu2.set('Value',8) %OG Audio
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\OGTrials.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Please confirm the trial information: OG trial?'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                if currCond == 9 %first OGPost
                    pause(breakTime); %4.5mins
                    play(AudioTimeUp);
                end            
            case 2 %tmbase slow
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\TMBaselineSlow.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 0.5m/s (TMBaselineSlow)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            case 3 %tm base fast
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\TMBaselineFast.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 1m/s (TMBaselineFast)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); %2.5mins
                play(AudioTimeUp);            
            case 4 %adaptation 1
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\Adaptation1_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\Adaptation1_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 150 strides with 0.75m/s, then R at 1m/s and L at 0.5m/s for 200 strides, then 25 strides with 0.75m/s (Adaptation1_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 150 strides with 0.75m/s, then L at 1m/s and R at 0.5m/s for 200 strides, then 25 strides with 0.75m/s (Adaptation1_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [150 350 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); %4.5mins
                play(AudioTimeUp);
            case {5,6,7} %adaptation 2-4
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\Adaptation2-4_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\Adaptation2-4_LeftDominant.mat';
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
                pause(breakTime); %4.5mins
                play(AudioTimeUp);            
            case 8 %adaptation5
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\Adaptation5_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\Adaptation5_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 25 strides at 0.75m/s, then 200 strides with R at 1m/s and L at 0.5m/s (Adaptation5_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 25 strides at 0.75m/s, then 200 strides with L at 1m/s and R at 0.5m/s (Adaptation5_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [25 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            case 11 %TMPost
                handles.popupmenu2.set('Value',11) %OPEN Loop
                profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\TMPostMid.mat';
                manualLoadProfile([],[],handles,profilename)
                button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 0.75m/s (TMPostMid)'); 
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [-1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
                pause(breakTime); %2.5mins
                play(AudioTimeUp);            
            case 12 %pos short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\PosShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\PosShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s (PosShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s (PosShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            case 14 %neg short
                handles.popupmenu2.set('Value',11) %OPEN Loop
                if dominantRight
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\NegShort_RightDominant.mat';
                else
                    profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\BrainWalk\Intervention\NegShort_LeftDominant.mat';
                end
                manualLoadProfile([],[],handles,profilename)
                if dominantRight
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s (NegShort_RightDominant)'); 
                else
                    button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s (NegShort_LeftDominant)'); 
                end
                if ~strcmp(button,'Yes')
                  return; %Abort starting the exp
                end
                numAudioCountDown = [50 -1];
                AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
        end %end of switch statement for v03
    
    elseif strcmpi(visitNum,'4(Post/DT)')
        %TODO: add switch here.
    end %end of the if else loop per visit
end %end of big while loop

%% Now transfer the data
transferDataAndSaveC3D_BrainWalk()
