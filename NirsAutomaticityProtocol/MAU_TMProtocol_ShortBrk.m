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
    maxCond = 15;
else
    maxCond = 16;
end

breakTime2min = 90;%this is shorter than 120s to give 40s for Vicon to start and stop. used to do225 = 4.5mins,
breakTime1min30 = 50; %1.5min. Used to do 110 = 2.5mins

%% Start protocol
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
        case {1,11,12,13} %OG trials w/o audio feedback
            handles.popupmenu2.set('Value',8) %OG Audio
            profilename = [profileDir 'OGTrials.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: OG trial?'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            if ismember(currCond,[11,12,13]) %first two OGPost
                pause(breakTime2min);
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
            pause(breakTime2min); 
            play(AudioTimeUp);
        case 4 %tm mid 100 strides
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMMid.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 100 strides with 0.75m/s (TMBaselineMid)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime2min); 
            play(AudioTimeUp);
        case 5 %mid then adapt
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'MidBaseAndAdaptation_RightDominant.mat'];
            else
                profilename = [profileDir 'MidBaseAndAdaptation_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides with 0.75m/s, then R at 1m/s and L at 0.5m/s for 150 strides (MidBaseAndAdaptation_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides with 0.75m/s, then L at 1m/s and R at 0.5m/s for 150 strides (MidBaseAndAdaptation_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime2min);
            play(AudioTimeUp);
        case {6,7,8,9,10} %adaptation last 150
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
            if ismember(currCond, [6:9])
                pause(breakTime2min); %4.5mins
                play(AudioTimeUp);
            end
        case 14 %TMPost
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMPost.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 0.75m/s (TMMid)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime1min30); %2.5mins
            play(AudioTimeUp);            
        case 15 %pos short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'PosShortAndPost_RightDominant.mat'];
            else
                profilename = [profileDir 'PosShortAndPost_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then tied for 50 strides (PosShortRamp_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then tied for 50 strides (PosShortRamp_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 80 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime1min30); %1.5mins
            play(AudioTimeUp); 
        case 16 %neg short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'NegShortAndPost_RightDominant.mat'];
            else
                profilename = [profileDir 'NegShortAndPost_LeftDominant.mat'];
            end
            manualLoadProfile([],[],handles,profilename)
            if dominantRight
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with L at 1m/s and R at 0.5m/s, then tied for 50 strides (NegShortRamp_RightDominant)'); 
            else
                button=questdlg('Confirm controller is Open loop controller with audio countdown. Profile is 50 strides at 0.75m/s, then 30 strides with R at 1m/s and L at 0.5m/s, then tied for 50 strides (NegShortRamp_LeftDominant)'); 
            end
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [50 80 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
    end

else %intervention
    %%
    profileDir = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\NirsAutomaticityStudy\MAuto3Visits\Intervention\';
    switch currCond
        case {1,10,11,12}%{1,9,10,13,15} %OG trials w/o audio feedback
            handles.popupmenu2.set('Value',8) %OG Audio
            profilename = [profileDir 'OGTrials.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: OG trial?'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            if ismember(currCond,[10:12]) %first OGPost
                pause(breakTime2min);
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
            pause(breakTime2min);
            play(AudioTimeUp);
        case 4 %mid 125 strides
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMBaselineMid.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 75 strides with 1m/s (TMBaselineFast)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime2min); 
            play(AudioTimeUp);
        case {5,6,7,8} %adaptation 2-4
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'Adaptation1-4_RightDominant.mat'];
            else
                profilename = [profileDir 'Adaptation1-4_LeftDominant.mat'];
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
            pause(breakTime2min); 
            play(AudioTimeUp);            
        case 9 %adaptation5
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
        case 13 %TMPost
            handles.popupmenu2.set('Value',11) %OPEN Loop
            profilename = [profileDir 'TMPostMid.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is 150 strides with 0.75m/s (TMMid)'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime1min30);
            play(AudioTimeUp);            
        case 14 %pos short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'PosShortAndPost_RightDominant.mat'];
            else
                profilename = [profileDir 'PosShortAndPost_LeftDominant.mat'];
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
            numAudioCountDown = [50 80 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(breakTime1min30); 
            play(AudioTimeUp); 
        case 15 %neg short
            handles.popupmenu2.set('Value',11) %OPEN Loop
            if dominantRight
                profilename = [profileDir 'NegShortAndPost_RightDominant.mat'];
            else
                profilename = [profileDir 'NegShortAndPost_LeftDominant.mat'];
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
            numAudioCountDown = [50 80 -1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    
    end
end
end
