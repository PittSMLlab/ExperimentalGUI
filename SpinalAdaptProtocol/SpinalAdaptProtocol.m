%This scripts will:
%1) generate speed profile for SpinalAdapt Study. Requires experimenter to
%come here and update subjectID, slow, mid, fast speed, and fast leg.
%2) automate experiment flow for TMBase slow and mid, then break for OG (needs experimenter input for speed feedback range)
%3) automate experiment flow from pre nirs train, then adaptation
%blocks, then post train, finish with pos and negative short.
%OG baseline conditions (3-5) will be run manually because OG with speed feedback need different speed range --> this will require
%manual change before each condition. 

%% set up trial condition and dominant leg for each participant
% EXPERIMENTER: Before each experiment, ENTER subject-specific speed and leg info 
subjectID = 'Test01';
slow = 0.5;
mid = 0.75;
fast = 1;

fastLeg = 'R';%Allowed entries: R or L, if don't know yet, leave as random and choose generate baseline only

profileDir = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\SpinalAdaptNirsStudy\' subjectID filesep];

%ask user if they want to generate profile, if so, baseline or adaptation
opts.Interpreter = 'tex';
opts.Default = 'No, I generated them already';
profileToGen = questdlg('Regenerate profile? Confirm in speed and subject ID are correct in SpinalAdaptProtocol.m ',...
    'RegenProfile','Baseline Only', 'Protocol After Baseline','No, I generated them already',opts);
switch profileToGen
    case 'Baseline Only'
        GenerateProfileSpinalStudy(slow, mid, fast, true, profileDir); %generate base only. 
%         return %if baseline only stop the script, will not auto continue to trials. Needs manual loading of profiles now.
    case 'Protocol After Baseline'
        %confirm again the fast leg is correct
        button=questdlg(["Will create profile where the fast leg is " fastLeg "Is that correct?"]);  
        if ~strcmp(button,'Yes')
           return; %Abort starting the tri
        end
        GenerateProfileSpinalStudy(slow, mid, fast, false, profileDir, fastLeg); %generate the rest after the dominant leg is determined    
    case 'No, I generated them already'
        %continue.
        disp('Profile generated already. Continue with the experiments')
    otherwise
        disp('No response given, quit the script now.')
        return
end
   
%% Set up GUI and run exp
%load audio for break time up.
[audio_data,audio_fs]=audioread('TimeIsUp.mp3');
AudioTimeUp = audioplayer(audio_data,audio_fs);

%load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename
global numAudioCountDown

maxCond = 14;

%% start the protocol
firstCond = true;
currCond = 0; %default value to start while loop.
while currCond < maxCond
    if ~firstCond
        nextCondButton=questdlg('Auto continue with next condition?');
        if strcmp(nextCondButton,'Yes') %automatically advance to next condition.
            currCond = currCond + 1;
        elseif strcmp(nextCondButton, 'No')
            %if said No to auto advance, ask where to start
            currCond = inputdlg('Which condition to start from (1 for baseline, 6 for pretrain, enter the number from the 1st col on the data sheet)? ');
            currCond = str2num(currCond{1});
            disp(['Starting from ' num2str(currCond)]);
        else %cancel
            return %stop exp
        end
    else
        firstCond = false;
        %always ask the first time.
        currCond = inputdlg('Which condition to start from (1 for baseline, 6 for pretrain, enter the number from the 1st col on the data sheet)? ');
        currCond = str2num(currCond{1});
        disp(['Starting from ' num2str(currCond)]);
    end
    
    switch currCond
        case 1 %TM base tied
            handles.popupmenu2.set('Value',11) %OPEN Loop with count down.
            profilename = [profileDir, 'TMBaseMid.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is TMBaseMid'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 2 %TM base slow
            handles.popupmenu2.set('Value',11) %OPEN Loop with count down.
            profilename = [profileDir, 'TMBaseSlow.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm controller is Open loop controller with audio countdown and profile is TMBaseSlow'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case {3,4,5} %OG
            handles.popupmenu2.set('Value',8) %OG Audio
            profilename = [profileDir 'OGTrials.mat'];
            manualLoadProfile([],[],handles,profilename)
            %now will ask user to change the speed info.
            button=questdlg('Please update audio feedback speed range');
%             if ~strcmp(button,'Yes')
            return; %Always return and quit because now needs experimenter change in OG controller for the next 3 trials.
%             end
%             AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
%             if currCond == 8 %first OGPost
%                 pause(225); %4.5mins
%                 play(AudioTimeUp);
%             end
        case 6 %pre train
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'PreSplitTrain.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: Nirs Train Pre?'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 12 %post nirs train
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'PostSplitTrain.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Please confirm the trial information: Nirs Train Post?'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 7 %1st adapt
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'Adapt1.mat'];
            manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is Adapt1'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(130); %~2.5mins
            play(AudioTimeUp);
        case {8,9,10,11} %adapt
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'Adapt2_5.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is Adapt2-5'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
            pause(130); %2.5mins
            play(AudioTimeUp);
        case 13 %pos short
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'PosShort.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is PosShort'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
        case 14 %neg short
            handles.popupmenu2.set('Value',14) %NIRS train
            profilename = [profileDir 'NegShort.mat'];manualLoadProfile([],[],handles,profilename)
            button=questdlg('Confirm trial and profile is NegShort'); 
            if ~strcmp(button,'Yes')
              return; %Abort starting the exp
            end
            numAudioCountDown = [-1];
            AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)
    end  
end
