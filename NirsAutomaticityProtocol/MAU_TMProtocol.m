%% set up trial condition and dominant leg for each participant
intervention = false; %true for visit 3, false for visit 2 and 4
dominantRight = true; %true if right dominant, false if left dominant

%% Set up GUI and run exp
%load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

[audio_data,audio_fs]=audioread('TimeIsUp.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

if intervention
    maxCond = 13;
else
    maxCond = 12;
end

%%
currCond = 0;

while currCond < maxCond
button=questdlg('Auto continue with next condition?');
if strcmp(button,'Yes') %automatically advance to next condition.
    currCond = currCond + 1;
else 
    %manually chose conditions
    currCond = inputdlg('What is the current condition number (1st column on the datasheet): ');
    currCond = str2num(currCond{1});
end

if ~intervention
    %% pre-post intervention
    profileDir = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\NirsAutomaticityStudy\MAuto3Visits\PrePostIntervention\';
    switch currCond
        case {1,8,9} %OG trials w/o audio feedback
            handles.popupmenu2.set('Value',8) %OG Audio
            profilename = [profileDir 'OGTrials.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: OG trial?'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            if currCond == 8 %first OGPost
                pause(225); %4.5mins
                play(AudioTimeUp);
            end
        case 2 %tmbase slow
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMBaselineSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 75 strides with 0.5m/s (TMBaselineSlow)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 3 %tm base fast
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMBaselineFast.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 75 strides with 1m/s (TMBaselineFast)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(110); %2.5mins
            play(AudioTimeUp);
        case 4 %mid then adapt
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'MidBaseAndAdaptation_RightDominant.mat'];
            else
                profilename = [profileDir 'MidBaseAndAdaptation_LeftDominant.mat'];
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
            pause(225); %4.5mins
            play(AudioTimeUp);
        case {5,6} %adaptation
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'Adaptation_RightDominant.mat'];
            else
                profilename = [profileDir 'Adaptation_LeftDominant.mat'];
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
            pause(225); %4.5mins
            play(AudioTimeUp);
        case 7 %adaptation last 150
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'Adaptation_150strides_RightDominant.mat'];
            else
                profilename = [profileDir 'Adaptation_150strides_LeftDominant.mat'];
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
            profilename = [profileDir 'TMMid.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 0.75m/s (TMMid)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(110); %2.5mins
            play(AudioTimeUp);            
        case 11 %pos short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'PosShortRamp_RightDominant.mat'];
            else
                profilename = [profileDir 'PosShortRamp_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with R at 1m/s and L at 0.5m/s, then tied for 50 strides (PosShortRamp_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with L at 1m/s and R at 0.5m/s, then tied for 50 strides (PosShortRamp_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 90 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(60); %1.5mins
            play(AudioTimeUp); 
        case 12 %neg short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'NegShortRamp_RightDominant.mat'];
            else
                profilename = [profileDir 'NegShortRamp_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with L at 1m/s and R at 0.5m/s, then tied for 50 strides (NegShortRamp_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with R at 1m/s and L at 0.5m/s, then tied for 50 strides (NegShortRamp_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 90 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
    end

else %intervention
    %%
    profileDir = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\NirsAutomaticityStudy\MAuto3Visits\Intervention\';
    switch currCond
        case {1,9,10}%{1,9,10,13,15} %OG trials w/o audio feedback
            handles.popupmenu2.set('Value',8) %OG Audio
            profilename = [profileDir 'OGTrials.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: OG trial?'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            if currCond == 9 %first OGPost
                pause(225); %4.5mins
                play(AudioTimeUp);
            end            
        case 2 %tmbase slow
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMBaselineSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 75 strides with 0.5m/s (TMBaselineSlow)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 3 %tm base fast
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMBaselineFast.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 75 strides with 1m/s (TMBaselineFast)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(110); %2.5mins
            play(AudioTimeUp);            
        case 4 %adaptation 1
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'Adaptation1_RightDominant.mat'];
            else
                profilename = [profileDir 'Adaptation1_LeftDominant.mat'];
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
            pause(225); %4.5mins
            play(AudioTimeUp);
        case {5,6,7} %adaptation 2-4
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'Adaptation2-4_RightDominant.mat'];
            else
                profilename = [profileDir 'Adaptation2-4_LeftDominant.mat'];
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
            pause(225); %4.5mins
            play(AudioTimeUp);            
        case 8 %adaptation5
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'Adaptation5_RightDominant.mat'];
            else
                profilename = [profileDir 'Adaptation5_LeftDominant.mat'];
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
            profilename = [profileDir 'TMPostMid.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 0.75m/s (TMMid)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(110); %2.5mins
            play(AudioTimeUp);            
        case 12 %pos short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'PosShortRamp_RightDominant.mat'];
            else
                profilename = [profileDir 'PosShortRamp_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with R at 1m/s and L at 0.5m/s, then tied for 50 strides (PosShortRamp_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with L at 1m/s and R at 0.5m/s, then tied for 50 strides (PosShortRamp_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 90 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(60); %1.5mins
            play(AudioTimeUp); 
        case 13 %neg short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'NegShortRamp_RightDominant.mat'];
            else
                profilename = [profileDir 'NegShortRamp_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with L at 1m/s and R at 0.5m/s, then tied for 50 strides (NegShortRamp_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 10 stride ramp to 30 strides with R at 1m/s and L at 0.5m/s, then tied for 50 strides (NegShortRamp_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 90 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
    end
end
end
