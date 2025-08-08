function [RTOTime, LTOTime, RHSTime, LHSTime, commSendTime, commSendFrame] = OGNBackTask(velL,velR,FzThreshold,profilename,mode,signList,paramComputeFunc,paramCalibFunc,trialType)
%Controller to run an auditory N-back task while walking overground. The
%controller requires:
%1) the wii controller set up, 
%2) fNIRS and Oxysoft plugged in and set up, 
%3) pregenerated sequences of n-back stimuli to play (these sequences should
%be saved in a folder on the path so that the code can load it). They need
%to be in naming convention: stand0-backSequences.mat,
%walk2-backSequences.mat, etc.
%4) pregenerated condition orders to run, they should follow specific
%naming conventions (see condOrder = load command below) and be on the path so that the code can load it.
%
% [Input]
%   - velL: number vector of left belt speed, size steps x1. not used but
%       followed other controller conventions. %TODO/Improvements: probably can
%       remove and clean up to make the controller more light-weighted and
%       respond faster
%   - velR: number array of right belt speed, size steps x1. not used but followed other controller conventions.
%   - FzThreshold: Fz threshold to detect a toe off/heel strike, not used
%   - profilename: string representing profile to load, not used but followed other controller conventions.
%   - mode: 1 or 0 for signed or unsigned for velocities i think, default 1
%   - signList: the caller will pass in []
%   - paramComputeFunc: the caller will pass in []
%   - paramCalibFunc: the caller will pass in []
%   - trialType: REQUIRED, string, representing what trial to run, the value should be set via a listdig in the previous step.
%       allowed values are (expect the exact same match) :{'Standing Familarization (can only run this up to 3 times)','Full Familarization (run through all conditions once)','Trial 1',...
%             'Trial 2','Trial 3','Trial 4','Trial 5','Trial 6'}
%
% [Output]
%   - RTOTime, LTOTime, RHSTime, LHSTime, commSendTime, commSendFrame
%
% $Author: Shuqi Liu $	$Date: 2025/02/14 10:12:38 $	$Revision: 0.1 $
% Copyright: Sensorimotor Learning Laboratory 2025
%
% FIXME: add another global var to control to pass the gui to avoid playing
% sound after clicking.

%% Parameters FIXed for this protocol (don't change it unless you know what you are doing)
oxysoft_present = true; 
timeEpsilon = 0.035; %tolerance for time elapsed within the target +- epsilon will count as in target window. e.g., if rest is 30s, timePassed = 20.99 to 30.01 will all be considered acceptable
%this one error propagates over time since every stimulus ISI will have a
%tolerance of 0.025, overtime the whole block might be off by 0.1-0.2ms
instructionAudioBufferSec = 2; %give 1s after playing the instruction before 1st number so that the 1st number can be heard well and not rushed. 
%Hard-coded to match what's in the GenerateNBackSequence.m
%Need at least a few ms, other wise the first number will be played as the instruction is finishing
recordData = false; %usually false now bc of headset problems, could turn off for debugging

twoClikerMode = 1; %0 for 1 clicker and only respond for match
%1 for using 1 clicker but 2 buttons, front for match and back for mismatch
%2 for using both clickers, 1 grey for match, 1 black for mistmatch. 

randMtd = ISIRandMethod.uniform;

if ISIRandMethod.pseudo == randMtd
    if twoClikerMode
        restDuration = 42; %for 2 clicker psuedo was 30s + 1s padding per task.
    else
        restDuration = 30; %used to default to 30 when using 1 clicker in the beginning.
    end
else
    restDuration = 40; %new protocol since 7/14/2025 decided to set total duration to 40s instead of 42 for BW02 and BW05
end

%% Parameter for randonization orde. If Option1, change the condOrderToRun (task randomization order) to run per person.
%Option1. run pseudorandom sequence, this order and the loading below go
%togehter
% condOption = 1;
% condOrderToRun = [1:6]; %permutations of 1:6, which pre-generated trial to run first
% condOrder = load('n-back-condOrder-FullPseudoRandom.mat'); %this loads condOrder
% condOrder = condOrder.condOrder;
% condOrder = condOrder(condOrderToRun,:);

% % %Option2. run orderedInTrial sequence (trial1 will be easy to hard, trial2
% % %will be hard to easy, then repeat)
% condOption = 2;
% condOrder = load('n-back-condOrder-orderedInTrial.mat'); %this loads condOrder
% condOrder = condOrder.condOrder; %use default order

% %Option3. run same difficulty n-back in a given trial, order the trials so
% %that the trials will be easy to hard then back to easy. I.e., trial1 is 0-back stand and walk/DT; 
% %trial2 is 1-back, trial3 is 2-back, then trial4 is 2-back, then 1-back, and 0-back
% condOption = 3;
% condOrder = load('n-back-condOrder-sameWithin_walkRep1_OrderedAcrossTrials012210.mat'); 
% condOrder = condOrder.condOrder; %use default order

% Option4. Same n in trial, but random n-orders across trials. 3 reps of walk, walkn, standn per trial, and each n
% is repeated twice for total 6 reps per condition (walk will have way more).
condOption = 4;
% condOrder = load('n-back-condOrder-sameWithinAllRep3_OrderedAcrossTrial210012.mat'); %this loads condOrder
condOrder = load('n-back-condOrder-sameWithinAllRep2_OrderedAcrossTrial210012.mat'); %this loads condOrder
condOrder = condOrder.condOrder;

%% Set up task sequence, recordings and main loop

%The trialtype is from a list dialog selection in AdaptationGUI, Assume always in order {'Standing Familarization (can only run this up to 3 times)','Full Familarization (run through all conditions once)','Trial 1',...
%             'Trial 2','Trial 3','Trial 4','Trial 5','Trial 6'}
% if contains(trialType,'Standing Familarization') %standing familiarization
%     nOrders = {'stand0','stand1','stand2'};
%     % Pop up window to confirm parameter setup, do this only once at the
%     % very first familarization trial.
%     button=questdlg('Please confirm that you have UPDATED the randomization_order of this participant, oxysoft_present is 1 (NIRS connected), rest duration is 30');  
%     if ~strcmp(button,'Yes')
%        return; %Abort starting the trial
%     end
%     nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
% elseif contains(trialType,'Full Familarization') %full trial familarization
%     nOrders = {'walk','stand0','stand1','stand2','walk0','walk1','walk2'};
%     nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
if startsWith(trialType,'Standing Familarization 0back') 
    nOrders = {'stand0-rep1'}
    % Pop up window to confirm parameter setup, do this only once at the
    % very first familarization trial.
    button=questdlg('Please confirm that you have UPDATED the randomization_order of this participant, oxysoft_present is 1 (NIRS connected), rest duration is 30 if one clicker, 42 if two clicker');  
    if ~strcmp(button,'Yes')
       return; %Abort starting the trial
    end
    nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
elseif startsWith(trialType,'Standing Familarization 1back') %full trial familarization
    nOrders = {'stand1-rep1'}
    nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
elseif startsWith(trialType,'Standing Familarization 2back') %full trial familarization
    nOrders = {'stand2-rep1'}
    nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
elseif startsWith(trialType,'Full Familarization 0back') 
    nOrders = {'stand0-rep1','walk0-rep1'}
    nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
elseif startsWith(trialType,'Full Familarization 1back') %full trial familarization
    nOrders = {'stand1-rep1','walk1-rep1'}
    nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.
elseif startsWith(trialType,'Full Familarization 2back') %full trial familarization
    nOrders = {'stand2-rep1','walk2-rep1'}
    nbackSeqRowIdx = 1; %All the n-back sequence is trial x stimuli matrix, this is the index to use for the current trial. Familiarization use row 1.

else %normal trial
    %the naming convention from the previous step's choice is always 'Trial
    %1', etc. so get last digit
    nbackSeqRowIdx = str2double(trialType(end));
    nOrders = condOrder(nbackSeqRowIdx,:) %find out in this trial, what order to run the conditions
    nbackSeqRowIdx = nbackSeqRowIdx + 1; %index that will be used to find n-back sequences to play, row1 is familarization, so each trial is offset by 1.
    %if there are repeats of the same task, needs to index multiple rows.
end

if condOption < 3 %no repeat within same trial, get rid of the suffix -rep1 from the familiarization hard-code
    nOrders = strrep(nOrders,'-rep1','');
end
%TODO/Improvement: using nOrders as strings are probably more readable but
%i think it's slower. Can map it to integer for easier comparisons, and to
%access the ISIs, sequence they can be in a 3D array (task x 2 (seq, ISI) x numbers)

%set up audio players
if twoClikerMode == 2 %2 clickers
    audioids = {'walk','walk0RightBtn','walk1','walk2','stand0RightBtn','stand1','stand2',...
        'relax','rest','stopAndRest','0','1','2','3','4','5','6','7','8','9'};
elseif twoClikerMode == 1 %1 clicker 2 button
    audioids = {'walk','walk0Thumb','walk1','walk2','stand0Thumb','stand1','stand2',...
        'relax','rest','stopAndRest','0','1','2','3','4','5','6','7','8','9'};
else
    audioids = {'walk','walk0','walk1','walk2','stand0','stand1','stand2',...
        'relax','rest','stopAndRest','0','1','2','3','4','5','6','7','8','9'};
end
%I-connected, R- rest or stop and rest,O-trialend(relax), W-walk, A-F for walk0-2, stand0-2, H,J-N,P-T for 0-10
eventCodeCharacter = {'W','A','B','C','D','E','F','O','R','R'}; 
numberCodeCharacter = {'H','J','K','L','M','N','P','Q','S','T'}; 
%TODO/Improvements: can maybe just use repeated letters to make it simpler. I think both of these codes are random, can probably even repeat the
%codes. we are not using these in processing; rather we are using the message to understand what happened

instructions = containers.Map();
for i = 1 : length(audioids)
%         disp(strcat(audioids{i},'.mp3'))
    [audio_data,audio_fs]=audioread(strcat(audioids{i},'.mp3'));
    curKey = strrep(audioids{i},'RightBtn',''); %use the same key for single and two clickers, even though audio file name is different
    curKey = strrep(audioids{i},'Thumb',''); %use the same key for single and two clickers, even though audio file name is different
    instructions(curKey) = audioplayer(audio_data,audio_fs);
end

%now remove the specific audio ID suffix to load general walk0/1/2 sequence
audioids = strrep(audioids,'RightBtn','');
audioids = strrep(audioids,'Thumb','');

% Load pre-generated task order, load the n-back sequences to use later, save them in key-value maps.
n_back_sequences = containers.Map();
for i = 2:7 %walk0-2, stand0-2
    fullSeq = load([char(randMtd) '-' audioids{i} '-backSequences.mat']);
    %optimize storage to save only the relevant rows and save effort for
    %indexing later.
    if condOption >= 3 %special case there is repeated conditions 
        %TODO: this is hard-coded for now, in theory the code can be smart to figure out how many reps there are in the nOrdersKey
        % and load the corresponding rows of sequences. (still require
        % histories of knowing when to start the index)
        if contains(trialType,'Familarization')
            startingIdx = 0; %will load sequences 1-3, but will only use 1
            repToLoad = 1;
        elseif str2double(trialType(end)) <= 3 %trial number, if first 3 trials, use 1-3 rep
            startingIdx = 1; %use row 2-4 since row1 is familiarization, later will do starting + j where j = 1:3
            repToLoad = 3;
        else
            startingIdx = 4; %use row 5-7, later will do starting + j where j = 1:3
            repToLoad = 3;
        end
        for j = 1:repToLoad %max 3 reps, load 3 sequnces. Here avoid using same variables bc indexing will be done multiple times
            seq.fullSequence = fullSeq.fullSequence(startingIdx+j,:);
            seq.fullTargetLocs = fullSeq.fullTargetLocs(startingIdx+j,:);
            seq.interStimIntervals = fullSeq.fullInterStimIntervals(startingIdx+j,:);
%             if twoClikerMode %give them 1 more second to respond
%                 if (i == 2 || i == 5) %walk0 or stand 0, use a different ISI bc instructions differ
                    if twoClikerMode == 2 %2 clicker, use the 2 interval
                        seq.interStimIntervals = fullSeq.fullInterStimIntervals2Clicker(startingIdx+j,:); %in ms 
                    elseif twoClikerMode == 1 %1 clicker 2 buttons use the 2button ISI
                        seq.interStimIntervals = fullSeq.fullInterStimIntervals2Buttons(startingIdx+j,:); %in ms 
                    else %1 clicker
                        seq.interStimIntervals =fullSeq.fullInterStimIntervals(startingIdx+j,:);
                    end
%             end
            seq.audioIdKey = audioids{i};
            seq.nirsEventCode = eventCodeCharacter{i};
            n_back_sequences([audioids{i} '-rep' num2str(j)]) = seq; 
            %save with the key matching the cond name convention ({'stand0-rep1','stand0-rep2',..'walk0-rep1',...,'walk-rep3'})
        end
    else %here can use same variable bc indexing only once
        fullSeq.fullSequence = fullSeq.fullSequence(nbackSeqRowIdx,:);
        fullSeq.fullTargetLocs = fullSeq.fullTargetLocs(nbackSeqRowIdx,:);
%         if twoClikerMode %give them 1 more second to respond
%             if (i == 2 || i == 5) %walk0 or stand 0, use a different ISI bc instructions differ
                if twoClikerMode == 2 %2 clicker, use the 2 interval
                    fullSeq.interStimIntervals = fullSeq.fullInterStimIntervals2Clicker(nbackSeqRowIdx,:); %in ms 
                elseif twoClikerMode == 1 %1 clicker 2 buttons use the 2button ISI
                    fullSeq.interStimIntervals = fullSeq.fullInterStimIntervals2Buttons(nbackSeqRowIdx,:); %in ms 
                else %for 1and 2back just simply add 1s ISI
                    fullSeq.interStimIntervals = fullSeq.fullInterStimIntervals(nbackSeqRowIdx,:) %in ms 
                end
%         end
        fullSeq.audioIdKey = audioids{i};
        fullSeq.nirsEventCode = eventCodeCharacter{i};
        n_back_sequences(audioids{i}) = fullSeq; %save with the key matching the cond name convention ({'s0','s1','s2','w0','w1','w2'})
    end
end

if recordData
    Fz = 48000;
    %try input 0 or 1, and output 2
    recObj = audiorecorder(Fz, 16, 1, 1); %Only need to change the last number, the input IDs
    record(recObj);
end

Oxysoft = nan;
if oxysoft_present
    Oxysoft = actxserver('OxySoft.OxyApplication');
end

%% set up from previous code
global feedbackFlag
if feedbackFlag==1  %&& size(get(0,'MonitorPositions'),1)>1
    ff=figure('Units','Normalized','Position',[1 0 1 1]);
    axis([0 length(velL)  0 2]);
    %Consider delete
    %     pp=gca;
%     ccc1=animatedline('Parent',pp,'Marker','o','LineStyle','none','MarkerFaceColor',[0 0 1],'MarkerEdgeColor','none');
%     ccc2=animatedline('Parent',pp,'Marker','o','LineStyle','none','MarkerFaceColor',[1 0 0],'MarkerEdgeColor','none');    
end

%TODO/Improvement: to clean up    
% paramLHS=0;
% paramRHS=0;
% lastParamLHS=0;
% lastParamRHS=0;
% lastRstepCount=0;
% lastLstepCount=0;
% LANK=zeros(1,6);
% RANK=zeros(1,6);
% RHIP=zeros(1,6);
% LHIP=zeros(1,6);
% LANKvar=1e5*ones(6);
% RANKvar=1e5*ones(6);
% RHIPvar=1e5*ones(6);
% LHIPvar=1e5*ones(6);
% lastLANK=nan(1,6);
% lastRANK=nan(1,6);
% lastRHIP=nan(1,6);
% lastLHIP=nan(1,6);
% toneplayed=false;

if nargin<7 || isempty(paramComputeFunc)
    paramComputeFunc=@(w,x,y,z) (-w(2) + .5*(y(2)+z(2)))/1000; %Default
end
[d,~,~]=fileparts(which(mfilename));
if nargin<8 || isempty(paramCalibFunc)
    load([d '\..\calibrations\lastCalibration.mat'])
else
    save([d '\..\calibrations\lastCalibration.mat'],'paramCalibFunc','paramComputeFunc')
end

if nargin<5 || isempty(mode)
    error('Need to specify control mode')
end
if nargin<6
    signList=[];
end
% signCounter=1; %Consider delete

global PAUSE%pause button value
global STOP
global enableMemory
global memory
global firstPress
global RFBClicker
if twoClikerMode
    global LFBClicker
end
STOP = false;

%Consider delete
% fo=4000;
% signS=0; %Initialize
% endTone=3*sin(2*pi*[1:2048]*fo*.025/4096);  %.5 sec tone at 100Hz, even with noise cancelling this is heard
% tone=sin(2*pi*[1:2048]*1.25*fo/4096); %.5 sec tone at 5kHz, even with noise cancelling this is heard

ghandle = guidata(AdaptationGUI);%get handle to the GUI so displayed data can be updated

%Consider delete
% %Initialize some graphical objects:
% ppp1=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','o','MarkerFaceColor',[0.68 .92 1],'MarkerEdgeColor','none');
% ppp2=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','o','MarkerFaceColor',[1 .6 .78],'MarkerEdgeColor','none');
% ppp3=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[0 0 1]);
% ppp4=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[1 0 0]);
% ppv1=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[0 .5 1]);
% ppv2=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[1 .5 0]);

yl=get(ghandle.profileaxes,'YLim');
%Add patches to show self-controlled strides:
aux1=diff(isnan(velL));
iL=find(aux1==1);
iL2=find(aux1==-1);
counter=1;
for i=1:length(iL)
    pp=patch([iL(i) iL2(i) iL2(i) iL(i)],[yl(1) yl(1) yl(2) yl(2)],[0 .3 .6],'FaceAlpha',.2,'EdgeColor','none');
    uistack(pp,'bottom')
    if (velL(iL(i))-velR(iL(i)))==0
        try
            auxT=signList(counter);
        catch
            if mode==0
                warning('Provided sign list seems to be shorter than # of null trials, adding default sign.')
            end
            signList(counter)=1;
            auxT=signList(counter);
        end
        counter=counter+1;
    else
        auxT=sign(velR(iL(i))-velL(iL(i)));
    end
    text(iL(i),yl(1)+.05*diff(yl),[num2str(auxT)],'Color',[0 0 1])
end
aux1=diff(isnan(velR));
iL=find(aux1==1);
iL2=find(aux1==-1);
counter=1;
for i=1:length(iL)
    pp=patch([iL(i) iL2(i) iL2(i) iL(i)],[yl(1) yl(1) yl(2) yl(2)],[.6 .3 0],'FaceAlpha',.2,'EdgeColor','none');
    uistack(pp,'bottom')
    if (velL(iL(i))-velR(iL(i)))==0
        try
            auxT=-signList(counter);
        catch
            if mode==0
                warning('Provided sign list seems to be shorter than # of null trials, adding default sign.')
            end
            signList(counter)=1;
            auxT=-signList(counter);
        end
        counter=counter+1;
    else
        auxT=sign(velL(iL(i))-velR(iL(i)));
    end
    text(iL(i),yl(1)+.1*diff(yl),[num2str(auxT)],'Color',[1 0 0])
end

% Consider delete
% t1 = [];

% %initialize a data structure that saves information about the trial,
datlog = struct();
datlog.buildtime = now;%timestamp
temp = datestr(datlog.buildtime,30); %Using ISO 8601 for date/time string format
a = regexp(temp,'-');
temp(a) = '_';
b = regexp(temp,':');
temp(b) = '_';
c = regexp(temp,' ');
temp(c) = '_';
[d,~,~]=fileparts(which(mfilename));
[~,n,~]=fileparts(profilename);
savename = [[d '\..\datlogs\'] temp '_' n];
set(ghandle.sessionnametxt,'String',[temp '_' n]);
datlog.session_name = savename;
datlog.errormsgs = {};
datlog.messages = {};
datlog.framenumbers.header = {'frame #','U Time','Relative Time'};
datlog.framenumbers.data = zeros(300*length(velR)+7200,2);
%Consider delete
% datlog.stepdata.header = {'Step#','U Time','frame #','Relative Time'};
% datlog.stepdata.RHSdata = zeros(length(velR)+50,3);%empty cell theoretically big enough to house all the steps taken
% datlog.stepdata.RTOdata = zeros(length(velR)+50,3);
% datlog.stepdata.LHSdata = zeros(length(velL)+50,3);
% datlog.stepdata.LTOdata = zeros(length(velL)+50,3);
% datlog.stepdata.paramLHS = zeros(length(velR)+50,1);
% datlog.stepdata.paramRHS = zeros(length(velL)+50,1);
datlog.audioCues.start = [];
datlog.audioCues.audio_instruction_message = {};
datlog.audioCues.recording={};
% datlog.response.header = {'Time','Block','n','Correctness','Index','Stimulus','ResponseTime','RelativeTime'};
datlog.response.dataheader = {'Time','ConditionIndex','CurrNumberIndex','CurrStimulus','ResponseKey(1R0L)','ResponseTime','Correct(1Correct0Wrong)'};
datlog.response.data = [];
datlog.response.conditionName = {};
%log the current sequence's correct locations (this is being extra
%cautious in case we couldn't figure out what order the conditions
%were done later no, but those orders are pregenerated so we should
%know)
datlog.stimulus.conditionOrder = nOrders;
datlog.stimulus.conditionName = {};
datlog.stimulus.conditionIndex = [];
datlog.stimulus.targetLocs = [];
datlog.stimulus.sequence = [];
datlog.stimulus.isi = [];

%Consider delete
% histL=nan(1,50);
% histR=nan(1,50);
% histCount=1;
% filtLHS=0;
% filtRHS=0;
% datlog.inclineang = [];
% datlog.speedprofile.velL = velL;
% datlog.speedprofile.velR = velR;
% datlog.speedprofile.signListForNullTrials = signList;
% datlog.TreadmillCommands.header = {'RBS','LBS','angle','U Time','Relative Time'};
% datlog.TreadmillCommands.read = nan(300*length(velR)+7200,4);
% datlog.TreadmillCommands.sent = nan(300*length(velR)+7200,4);%nan(length(velR)+50,4);
% datlog.Markers.header = {'x','y','z'};
% datlog.Markers.LHIP = nan(300*length(velR)+7200,3);
% datlog.Markers.RHIP = nan(300*length(velR)+7200,3);
% datlog.Markers.LANK = nan(300*length(velR)+7200,3);
% datlog.Markers.RANK = nan(300*length(velR)+7200,3);
% datlog.Markers.LHIPfilt = nan(300*length(velR)+7200,6);
% datlog.Markers.RHIPfilt = nan(300*length(velR)+7200,6);
% datlog.Markers.LANKfilt = nan(300*length(velR)+7200,6);
% datlog.Markers.RANKfilt = nan(300*length(velR)+7200,6);
% datlog.Markers.LHIPvar = nan(300*length(velR)+7200,36);
% datlog.Markers.RHIPvar = nan(300*length(velR)+7200,36);
% datlog.Markers.LANKvar = nan(300*length(velR)+7200,36);
% datlog.Markers.RANKvar = nan(300*length(velR)+7200,36);
% datlog.stepdata.paramComputeFunc=func2str(paramComputeFunc);
% if mode==4
%     datlog.stepdata.paramCalibFunc=func2str(paramCalibFunc);
% end

%do initial save
try
    save(savename,'datlog');
catch ME
    disp(ME);
end
%Consider delete
% %Default threshold
% if nargin<3
%     FzThreshold=40; %Newtons (40 is minimum for noise not to be an issue)
% elseif FzThreshold<40
%     %     warning = ['Warning: Fz threshold too low to be robust to noise, using 30N instead'];
%     datlog.messages{end+1} = 'Warning: Fz threshold too low to be robust to noise, using 40N instead';
%     disp('Warning: Fz threshold too low to be robust to noise, using 40N instead');
%     FzThreshold=40;
% end

%Check that velL and velR are of equal length
%Consider delete
N=length(velL)+1;
if length(velL)~=length(velR)
    disp('WARNING, velocity vectors of different length!');
    datlog.messages{end+1} = 'Velocity vectors of different length selected';
end
%Adding a fake step at the end to avoid out-of-bounds indexing, but those
%speeds should never get used in reality:
velL(end+1)=0;
velR(end+1)=0;

%Initiate variables, this is needed to return them out to the caller fcn
RTOTime(N) = now;
LTOTime(N) = now;
RHSTime(N) = now;
LHSTime(N) = now;
commSendTime=zeros(2*N-1,6);
commSendFrame=zeros(2*N-1,1);

%Initialize nexus & treadmill communications
try
    %Consider delete
%     Client.LoadViconDataStreamSDK();
%     MyClient = Client();
%     Hostname = 'localhost:801';
%     out = MyClient.Connect(Hostname);
%     out = MyClient.EnableMarkerData();
%     out = MyClient.EnableDeviceData();
%     MyClient.SetStreamMode(StreamMode.ClientPullPreFetch);

    HostName = 'localhost:801';
%     fprintf( 'Loading SDK...' );
    addpath( '..\dotNET' );
    dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
    if dssdkAssembly == ""
        [ file, path ] = uigetfile( '*.dll' );
        dssdkAssembly = fullfile( path, file );
      
    end

    NET.addAssembly(dssdkAssembly);
    MyClient = ViconDataStreamSDK.DotNET.Client();
    MyClient.Connect( HostName );
    %Consider delete
    % Enable some different data types
%     out =MyClient.EnableSegmentData();
%     out =MyClient.EnableMarkerData();
%     out=MyClient.EnableUnlabeledMarkerData();
%     out=MyClient.EnableDeviceData();
    
    MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );
      %Consider delete
%     mn={'LHIP','RHIP','LANK','RANK'};
%     altMn={'LGT','RGT','LANK','RANK'};
catch ME
    disp('Error in creating Nexus Client Object/communications see datlog for details');
    datlog.errormsgs{end+1} = 'Error in creating Nexus Client Object/communications';
    datlog.errormsgs{end+1} = ME;%store specific error
    disp(ME);
end

%Consider delete --- not doing TM walking
% try
% %     t = openTreadmillComm();
% catch ME
%     disp('Error in creating TCP connection to Treadmill, see datlog for details...');
%     datlog.errormsgs{end+1} = 'Error in creating TCP connection to Treadmill';
%     datlog.errormsgs{end+1} = ME;
%     disp(ME);
% end

try %So that if something fails, communications are closed properly
    MyClient.GetFrame();
    datlog.messages{end+1} = ['Nexus and Bertec Interfaces initialized: ' num2str(now)];
    
    %Consider delete -- not used
    %     y_max = 4250;%0 treadmill, max = 4.25meter ~= 13.94 ft = 6-7 tiles
%     y_min = -2300;%0 treadmill, min = 2.3meter ~=7.55 ft = 3-4 tiles 
%     
%     LHS_time = 0;
%     RHS_time = 0;
%     LHS_pos = 0;
%     RHS_pos = 0;
%     HS_frame = 0;
%     pad = 50;
    
    %Connect to Oxysoft
    % Write event I with description 'Instructions' to Oxysoft
    datlog = nirsEvent('', 'I', ['Connected ',trialType], instructions, datlog, Oxysoft, oxysoft_present);
    enableMemory = false; %setting up trials, doesn't allow clicking.

    %start with a rest block
    disp('Rest');
    currentIndex = 1; %current index for the condition in the block
    nirsRestEventString = generateNbackRestEventString(nOrders, currentIndex);
    datlog = nirsEvent('rest', 'R', nirsRestEventString, instructions, datlog, Oxysoft, oxysoft_present);
    pause(restDuration);
    
    if strcmp(nOrders{currentIndex},'walk') || startsWith(nOrders{currentIndex},'walk-rep') %first task is walk
        datlog = nirsEvent('walk','W','walk', instructions, datlog, Oxysoft, oxysoft_present); %walk always use event code W
        tStart=clock; %start the clock right after saying walk
        enableMemory = false;
        sequenceComplete = false; 
    else
        %get the value from the map of the current condition key
        %nOrders{currentIndex} are str format of task to run, e.g., 's0','w0' etc.
        currSequence = n_back_sequences(nOrders{currentIndex}).fullSequence;
        ISIs = (n_back_sequences(nOrders{currentIndex}).interStimIntervals)./1000; %convert into seconds bc that's 
        totalNums = size(currSequence,2);
        
        %log the current sequence's correct locations (this is being extra
        %cautious in case we couldn't figure out what order the conditions
        %were done later no, but those orders are pregenerated so we should
        %know)
        datlog.stimulus.conditionName{end+1} = nOrders{currentIndex};
        datlog.stimulus.conditionIndex(end+1) = currentIndex;
        datlog.stimulus.targetLocs(end+1,:) = n_back_sequences(nOrders{currentIndex}).fullTargetLocs;
        datlog.stimulus.sequence(end+1,:) = currSequence;
        datlog.stimulus.isi(end+1,:) = ISIs;
        
        enableMemory = false; %doesn't allow clicking when giving n-back instructions for what n to do.
        datlog = nirsEvent(n_back_sequences(nOrders{currentIndex}).audioIdKey,n_back_sequences(nOrders{currentIndex}).nirsEventCode,n_back_sequences(nOrders{currentIndex}).audioIdKey,...
            instructions, datlog, Oxysoft, oxysoft_present);
        %pause for instruction to finish before reading the numbers
        pause(instructionAudioBufferSec+instructions(n_back_sequences(nOrders{currentIndex}).audioIdKey).TotalSamples/instructions(n_back_sequences(nOrders{currentIndex}).audioIdKey).SampleRate)
        sequenceComplete = false; %reset variables
        numIndex = 1;
        currNumInStr = num2str(currSequence(numIndex));
        %play the number and log a number event, the nirsEventId is random code indexed by the number (1based index, so offset by 1)
        datlog = nirsEvent(currNumInStr, numberCodeCharacter{currSequence(numIndex)+1}, currNumInStr,instructions, datlog, Oxysoft, oxysoft_present);
        tStart=clock; %start the clock right after saying the number
        enableMemory = true; %allow clicking now, first number started.
    end
    
    %Send first speed command & store
    commSendTime(1,:)=clock;

    %% Main loop
    
    old_velR = libpointer('doublePtr',velR(1));
    old_velL = libpointer('doublePtr',velL(1));
    frameind = libpointer('doublePtr',1);
    framenum = libpointer('doublePtr',0);
    
    %Get first frame
    MyClient.GetFrame();
    framenum.Value = MyClient.GetFrameNumber().FrameNumber;
    datlog.framenumbers.data(frameind.Value,:) = [framenum.Value now];
    
    while ~STOP %only runs if stop button is not pressed
        pause(.001) %This ms pause is required to allow Matlab to process callbacks from the GUI.
        %It actually takes ~2ms, as Matlab seems to be incapable of pausing for less than that (overhead of the pause() function, I presume)
        while PAUSE %only runs if pause button is pressed
            pause(.2);
            datlog.messages{end+1} = ['Loop paused at ' num2str(now)];
            disp(['Paused at ' num2str(clock)]);
            %do a quick save
            try
                save(savename,'datlog');
            catch ME
                disp(ME);
            end
            old_velR.Value = 1;%change the old values so that the treadmill knows to resume when the pause button is resumed
            old_velL.Value = 1;
        end
        
        %Read frame, update necessary structures4
        MyClient.GetFrame();
        framenum.Value = MyClient.GetFrameNumber().FrameNumber;
        
        %Check if any clicking happened
        if RFBClicker == 1 %subject responsed, check if correct (participant clicked/responded match, which can be clicking grey/first paired controller or clicking A with thumb)
            RFBClicker =0; %reset the value
            responseT = clock - tStart;
            responseT = abs((responseT(4)*3600)+(responseT(5)*60)+responseT(6)); %his is in second
            
            %Save {'Time','ConditionIndex','CurrNumberIndex','CurrStimulus','ResponseKey(1R0L)','ResponseTime','Correct(1Correct0Wrong)'};
            %Save the condition name (e.g., walk-rep1, walk0-rep3, etc.) in a separate
            %array datlog.response.conditionName to make the response.data
            %a numerical array which is easier to manipulate
            %with CurrNumberIndex we can calculate correctness later on, basically all the index participant responseded should = targetLoc
            %Right click is for correct/match, so the numIndex
            %should be a member of the target
            datlog.response.data(end+1,:) = [now, currentIndex, numIndex, currSequence(numIndex), ...
                1,responseT, ismember(numIndex,n_back_sequences(nOrders{currentIndex}).fullTargetLocs)];
            datlog.response.conditionName{end+1} = nOrders{currentIndex};
            %Separating the string entry and the other numerical entry may be helpful for performance: https://stackoverflow.com/questions/16243523/matlab-data-structure-for-mixed-type-whats-time-space-efficient
            %keep numerical elements together for easier numerical manipulation and perhaps performance
            
            fprintf('Clicked R (match) on stimulus: %d, Correctness (1Correct0Incorrect): %d\n', currSequence(numIndex), datlog.response.data(end,end))
        end
        
        if twoClikerMode && (~isempty(LFBClicker)) && LFBClicker == 1 %two clicker mode and subject responseded, check if correct (participant responded mismatch, which came from clicking 2nd paired controller or clicking index finger on the back)
            LFBClicker =0; %reset the value
            responseT = clock - tStart;
            responseT = abs((responseT(4)*3600)+(responseT(5)*60)+responseT(6)); %his is in second
            
            %Save {'Time','ConditionIndex','CurrNumberIndex','CurrStimulus','ResponseKey(1R0L)','ResponseTime','Correct(1Correct0Wrong)'};
            %Save the condition name (e.g., walk-rep1, walk0-rep3, etc.) in a separate
            %array datlog.response.conditionName to make the response.data
            %a numerical array which is easier to manipulate
            %with CurrNumberIndex we can calculate correctness later on, basically all the index participant responseded should = targetLoc
            %Right click is for correct/match, so the numIndex
            %should be a member of the target
            datlog.response.data(end+1,:) = [now, currentIndex, numIndex, currSequence(numIndex), ...
                0,responseT, ~ismember(numIndex,n_back_sequences(nOrders{currentIndex}).fullTargetLocs)];
            datlog.response.conditionName{end+1} = nOrders{currentIndex};
            %Separating the string entry and the other numerical entry may be helpful for performance: https://stackoverflow.com/questions/16243523/matlab-data-structure-for-mixed-type-whats-time-space-efficient
            %keep numerical elements together for easier numerical manipulation and perhaps performance
            
            fprintf('Clicked L (mis-match) on stimulus: %d, Correctness (1Correct0Incorrect): %d\n', currSequence(numIndex), datlog.response.data(end,end))
        end
        
        if framenum.Value~= datlog.framenumbers.data(frameind.Value,1) %Frame num value changed, reading data
            frameind.Value = frameind.Value+1; %Frame counter
            datlog.framenumbers.data(frameind.Value,:) = [framenum.Value now];
                        
            %Read markers:
%             sn=MyClient.GetSubjectName(0).SubjectName;
%             l=1;
%             md=MyClient.GetMarkerGlobalTranslation(sn,mn{l});
% 
%             md_LHIP=MyClient.GetMarkerGlobalTranslation(sn,altMn{1});
%             md_RHIP=MyClient.GetMarkerGlobalTranslation(sn,altMn{2});
%             md_LANK=MyClient.GetMarkerGlobalTranslation(sn,mn{3});
%             md_RANK=MyClient.GetMarkerGlobalTranslation(sn,mn{4});

            %Maybe delete?? not using marker data for any real-time update
%             if strcmp(md.Result,'Success') %md.Result.Value==2 %%Success getting marker
%                 aux=double(md.Translation);
% 
% 
%                 LHIP_pos = double(md_LHIP.Translation);
%                 RHIP_pos = double(md_RHIP.Translation);
%                 LANK_pos = double(md_LANK.Translation);
%                 RANK_pos = double(md_RANK.Translation);
%             else
%                 md=MyClient.GetMarkerGlobalTranslation(sn,altMn{l});
%                 if strcmp(md.Result,'Success') % md.Result.Value==2
%                     aux=double(md.Translation);
%                     LHIP_pos = double(md_LHIP.Translation);
%                     RHIP_pos = double(md_RHIP.Translation);
%                     LANK_pos = double(md_LANK.Translation);
%                     RANK_pos = double(md_RANK.Translation);
%                 else
%                     aux=[nan nan nan]';
%                     LHIP_pos = [nan nan nan]';
%                     RHIP_pos = [nan nan nan]';
%                     LANK_pos = [nan nan nan]';
%                     RANK_pos = [nan nan nan]';
%                 end
%                 if all(aux==0) || all(LHIP_pos==0) || all(RHIP_pos==0) || all(LANK_pos==0) || all(RANK_pos==0)
%                     %Nexus returns 'Success' values even when marker is missing, and assigns it to origin!
%                     %warning(['Nexus is returning origin for marker position of ' mn{l}]) %This shouldn't happen
%                     aux=[nan nan nan]';
%                     LHIP_pos = [nan nan nan]';
%                     RHIP_pos = [nan nan nan]';
%                     LANK_pos = [nan nan nan]';
%                     RANK_pos = [nan nan nan]';
%                 end
%             end
            %aux
            %Here we should implement some Kalman-like filter:
            %eval(['v' mn(l) '=.8*v' mn(l) '+ (aux-' mn(l) ');']);
%             eval(['lastEstimate=' mn{l} ''';']); %Saving previous estimate
%             eval(['last' mn{l} '=lastEstimate'';']); %Saving previous estimate as row vec
%             eval(['lastEstimateCovar=' mn{l} 'var;']); %Saving previous estimate's variance
%             eval(['datlog.Markers.' mn{l} '(frameind.Value,:) = aux;']);%record the current read

            elapsedFramesSinceLastRead=framenum.Value-datlog.framenumbers.data(frameind.Value-1,1);
            %What follows assumes a 100Hz sampling rate
            n=elapsedFramesSinceLastRead;
            if n<0
                error('inconsistent frame numbering')
            end
            
            %% Check if can remove, we don't need this for speed feedback.
            % added by Yashar to count steps OG and for verbal feedback action

%             set(ghandle.text25,'String',num2str(framenum.Value/100));
%             body_y_pos(frameind.Value) = (LHIP_pos(2)+RHIP_pos(2))/2;
%             body_y_pos_diff(frameind.Value) = body_y_pos(frameind.Value) - body_y_pos(frameind.Value-1);
%             Ank_diff(frameind.Value) = LANK_pos(2) - RANK_pos(2);
%             Ank_diffdiff(frameind.Value) = Ank_diff(frameind.Value)-Ank_diff(frameind.Value-1);
% 
%             if body_y_pos(frameind.Value) > y_min && body_y_pos(frameind.Value) < y_max && framenum.Value-HS_frame>pad
% 
%                 if body_y_pos_diff(frameind.Value) >= 0 && Ank_diffdiff(frameind.Value) >= 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1)) 
%                     Left_HS(frameind.Value) = 1;
%                     sumiL = sum(Left_HS);
%                     HS_frame = framenum.Value;
%                     LHS_time = [LHS_time framenum.Value/100];
%                     LHS_pos = [LHS_pos body_y_pos(frameind.Value)/1000];
%                     OG_speed_left = (LHS_pos(end)-LHS_pos(end-1))/(LHS_time(end)-LHS_time(end-1));
% 
%                     set(ghandle.LBeltSpeed_textbox,'String',num2str(OG_speed_left));
%                     set(ghandle.Left_step_textbox,'String',num2str(sumiL));
% 
%                     addpoints(ppp3,sumiL,OG_speed_left)
%                     %addpoints(ppv1,sumiL,sumiL/1000)%paramCalibFunc(paramLHS)/1000)
% 
%                 elseif body_y_pos_diff(frameind.Value) >= 0 && Ank_diffdiff(frameind.Value) < 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
%                     Right_HS(frameind.Value) = 1;
%                     sumiR = sum(Right_HS);
%                     HS_frame = framenum.Value;
%                     RHS_time = [RHS_time framenum.Value/100];
%                     RHS_pos = [RHS_pos body_y_pos(frameind.Value)/1000];
%                     OG_speed_right = (RHS_pos(end)-RHS_pos(end-1))/(RHS_time(end)-RHS_time(end-1));
% 
%                     set(ghandle.RBeltSpeed_textbox,'String',num2str(OG_speed_right));
%                     set(ghandle.Right_step_textbox,'String',num2str(sumiR))
% 
%                     addpoints(ppp4,sumiR,OG_speed_right);
%                     %addpoints(ppv2,sumiR,sumiR/1000)%paramCalibFunc(paramRHS)/1000)
% 
%                 elseif body_y_pos_diff(frameind.Value) < 0 && Ank_diffdiff(frameind.Value) >= 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
%                     Right_HS(frameind.Value) = 1;
%                     sumiR = sum(Right_HS);
%                     HS_frame = framenum.Value;
%                     RHS_time = [RHS_time framenum.Value/100];
%                     RHS_pos = [RHS_pos body_y_pos(frameind.Value)/1000];
%                     OG_speed_right = abs((RHS_pos(end)-RHS_pos(end-1))/(RHS_time(end)-RHS_time(end-1)));
% 
%                     set(ghandle.RBeltSpeed_textbox,'String',num2str(OG_speed_right));
%                     set(ghandle.Right_step_textbox,'String',num2str(sumiR))
% 
%                     addpoints(ppp4,sumiR,OG_speed_right)
% 
%                 elseif body_y_pos_diff(frameind.Value) < 0 && Ank_diffdiff(frameind.Value) < 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
%                     Left_HS(frameind.Value) = 1;
%                     sumiL = sum(Left_HS);
%                     HS_frame = framenum.Value;
%                     LHS_time = [LHS_time framenum.Value/100];
%                     LHS_pos = [LHS_pos body_y_pos(frameind.Value)/1000];
%                     OG_speed_left = abs((LHS_pos(end)-LHS_pos(end-1))/(LHS_time(end)-LHS_time(end-1)));
% 
%                     set(ghandle.LBeltSpeed_textbox,'String',num2str(OG_speed_left));
%                     set(ghandle.Left_step_textbox,'String',num2str(sumiL));
% 
%                     addpoints(ppp3,sumiL,OG_speed_left)
%                 end
%                     
%             elseif body_y_pos(frameind.Value) <= y_min
%                 %reach one end (computer side)
% %                 t1(end+1,:) = clock;
% %                 disp('Reaching t1')
%             elseif body_y_pos(frameind.Value) >= y_max
%                 %reach the door side
% %                 t2 = clock;
% %                 disp('Reaching t2')
%             end
            
            %% logic to check if should advancing to next event
            tEnd = clock;
            t_diff = tEnd - tStart;
            t_diff = abs((t_diff(4)*3600)+(t_diff(5)*60)+t_diff(6)); %this is in seconds
            
            %time to play next number: if it's not a walk trial, and the required ISI for this number has passed.
            %If it's the response window after the last number, mark trial as complete.
%             if (~strcmp(nOrders{currentIndex},'w'))&& (t_diff >= ISIs(numIndex)-timeEpsilon && t_diff <= ISIs(numIndex) + timeEpsilon) 
            if (~strcmp(nOrders{currentIndex},'walk')) && (~startsWith(nOrders{currentIndex},'walk-rep')) && (t_diff >= ISIs(numIndex)-timeEpsilon) %once pass ISI lower threshold continue, to avoid slow loop rate to cause up to be stuck 
                if numIndex < totalNums %last possible options is totalNum-1 bc will increment1 right away
                    %now go to next number
                    numIndex = numIndex + 1;
                    currNumInStr = num2str(currSequence(numIndex));
%                     enableMemory = true; %trial started, allow clicking (perhaps not needed)
                    datlog = nirsEvent(currNumInStr, numberCodeCharacter{currSequence(numIndex)+1}, currNumInStr,instructions, datlog, Oxysoft, oxysoft_present);
                    tStart = clock;
                else %waited 1.5s after the last number, now can play stop and rest.
                    sequenceComplete = true;
                end
            end
            
            %check for passing minDuration only, don't check for upper
            %bound
            %TODO this is buggy
            if ((~strcmp(nOrders{currentIndex},'walk')) && ~startsWith(nOrders{currentIndex},'walk-rep') && sequenceComplete) || ((strcmp(nOrders{currentIndex},'walk') || startsWith(nOrders{currentIndex},'walk-rep')) && (t_diff >= restDuration-timeEpsilon)) % && t_diff <= restDuration +timeEpsilon))
                %if walk+DT, stop after full sequence is played. 
                %Or if walk only, and enough time hsa passed, say stop and rest, use round in case couldn't get exactly 20s, so will
                %stop from 19.999 ~ 20.001 seconds
                fprintf('time diff: %f\n',t_diff)
                
                %finished 1 task, increment the task index
                currentIndex = currentIndex + 1; %started one of the walking task, increment currentIndex.
                
                %if it's familiarization and it's the last rest, don't say
                %anything (familiarization doesn't have an ending rest)
%                 if ~contains(trialType,'Familarization') || currentIndex <= length (nOrders)
                if currentIndex <= length (nOrders) %more task to come, do a rest before
                    %log the rest before the next condition (e.g., if next is
                    %walk, will log Rest_before_walk)
                    nirsRestEventString = generateNbackRestEventString(nOrders, currentIndex);
                    datlog = nirsEvent('stopAndRest','R',nirsRestEventString, instructions, datlog, Oxysoft, oxysoft_present);
                    enableMemory = false; %doesn't allow click during stop and rest
%                     if currentIndex > length(nOrders) %last rest in an actual trial, make it shorter
%                         pause(restDuration);
%                     else
                        pause(restDuration);
%                     end
                end

                if currentIndex > length (nOrders) %next trial is the end of the block
%                     currentIndex = 1; %reset the current index
%                     trialIndex = trialIndex + 1;
%                     if (trialIndex >  size(nOrders,1))
                        STOP = 1;
                        datlog = nirsEvent('relax','O','Trial_End', instructions, datlog, Oxysoft, oxysoft_present);
                        enableMemory = false; %not allow click after trial end.
                        pause(1.5) %give it 1 sec to say the relax
%                     else  %Restart a trial, currently should never be here
%                         warning('Check your code. Should not be in this code block.');
%                     end
                end
                
                if STOP ~=1 %experiment not over yet, load the next condition
                    if strcmp(nOrders{currentIndex},'walk') || startsWith(nOrders{currentIndex},'walk-rep') %next block is walk only
                        datlog = nirsEvent('walk','W','walk', instructions, datlog, Oxysoft, oxysoft_present); %walk always use event code W
                        tStart=clock; %start the clock right after saying Walk
                        enableMemory = false; %doesn't allow clicking for walk only trials.
                        sequenceComplete = false; %reset variables
                        numIndex = 1;
                    else %next block is n-back
                        %get the value from the map of the current condition key
                        %nOrders{currentIndex} are str format of task to run, e.g., 's0','w0' etc.
                        currSequence = n_back_sequences(nOrders{currentIndex}).fullSequence;
                        ISIs = (n_back_sequences(nOrders{currentIndex}).interStimIntervals)./1000; %convert to in seconds
                        totalNums = size(currSequence,2);
                        
                        %log the current sequence's correct locations (this is being extra
                        %cautious in case we couldn't figure out what order the conditions
                        %were done later no. Those orders are pregenerated so we should
                        %know, but in case of experimenter error we didn't run in order as planned etc., and make the datlog self-contained)
                        datlog.stimulus.conditionName{end+1} = nOrders{currentIndex};
                        datlog.stimulus.conditionIndex(end+1) = currentIndex;
                        datlog.stimulus.targetLocs(end+1,:) = n_back_sequences(nOrders{currentIndex}).fullTargetLocs;
                        datlog.stimulus.sequence(end+1,:) = currSequence;
                        datlog.stimulus.isi(end+1,:) = ISIs;
                        
                        enableMemory = false; %doesn't allow clicking when giving n-back instructions
                        datlog = nirsEvent(n_back_sequences(nOrders{currentIndex}).audioIdKey,n_back_sequences(nOrders{currentIndex}).nirsEventCode,n_back_sequences(nOrders{currentIndex}).audioIdKey,...
                            instructions, datlog, Oxysoft, oxysoft_present);
                        %pause to wait for the instruction to play before
                        %saying first number. Pause for the exact length
                        %the audio file is to avoid delaying/messing up
                        %with the total trial duration too much.
                        pause(instructionAudioBufferSec + instructions(n_back_sequences(nOrders{currentIndex}).audioIdKey).TotalSamples/instructions(n_back_sequences(nOrders{currentIndex}).audioIdKey).SampleRate)
                        numIndex = 1;
                        sequenceComplete = false; %reset variables
                        currNumInStr = num2str(currSequence(numIndex));
                        datlog = nirsEvent(currNumInStr, numberCodeCharacter{currSequence(numIndex)+1}, currNumInStr,instructions, datlog, Oxysoft, oxysoft_present);
                        tStart = clock; %start the clock right after reading the next number
                        enableMemory = true; %n-back trial starts, allow clicking.
                    end
                end
            end                        
        end
%     end
    end %While, when STOP button is pressed
    if STOP
        datlog.messages{end+1} = ['Stop button pressed at: ' num2str(now) ' ,stopping... '];
        disp(['Stop button pressed, stopping... ' num2str(clock)]);
        set(ghandle.Status_textbox,'String','Stopping...');
        set(ghandle.Status_textbox,'BackgroundColor','red');
    else
    end
catch ME
    datlog.errormsgs{end+1} = 'Error ocurred during the control loop';
    datlog.errormsgs{end+1} = ME;
    disp(ME)
    ME.getReport
    disp('Error ocurred during the control loop, see datlog for details...');
end

%% Closing routine
%End communications
global addLog
try
    aux = cellfun(@(x) (x-datlog.framenumbers.data(1,2))*86400,addLog.keypress(:,2),'UniformOutput',false);
    addLog.keypress(:,2)=aux;
    addLog.keypress=addLog.keypress(cellfun(@(x) ~isempty(x),addLog.keypress(:,1)),:); %Eliminating empty entries
    datlog.addLog=addLog;
catch ME
    ME
end
try
    save(savename,'datlog');
catch ME
    disp(ME);
end

disp('closing comms');
try
    disp('Closing Nexus Client') 
    disp(clock);
    closeNexusIface(MyClient);
%     closeTreadmillComm(t);
    disp('Done Closing');
    disp(clock);
catch ME
    datlog.errormsgs{end+1} = ['Error ocurred when closing communications with Nexus & Treadmill at ' num2str(clock)];
    datlog.errormsgs{end+1} = ME;
    disp(['Error ocurred when closing communications with Nexus & Treadmill, see datlog for details ' num2str(clock)]);
    disp(ME);
end

%convert keypress? %TODO/Improvement: is this needed? Shuqi added 8/16/2022, copied from marcela's code
global addLog
try
    aux = cellfun(@(x) (x-datlog.framenumbers.data(1,2))*86400,addLog.keypress(:,2),'UniformOutput',false);
    addLog.keypress(:,2)=aux;
    addLog.keypress=addLog.keypress(cellfun(@(x) ~isempty(x),addLog.keypress(:,1)),:); %Eliminating empty entries
    datlog.addLog=addLog;
catch ME
    ME
end

disp('converting time in datlog...');
try
%convert time data into clock format then re-save
datlog.buildtime = datestr(datlog.buildtime);

%convert frame times & markers
temp = find(datlog.framenumbers.data(:,1)==0,1,'first');
datlog.framenumbers.data(temp:end,:) = [];
for z = 1:temp-1
    datlog.framenumbers.data(z,3) = etime(datevec(datlog.framenumbers.data(z,2)),datevec(datlog.framenumbers.data(1,2)));
end

%convert audio times
datlog.audioCues.start = datlog.audioCues.start';
datlog.audioCues.audio_instruction_message = datlog.audioCues.audio_instruction_message';
temp = isnan(datlog.audioCues.start);
disp('\nConverting datalog, current starts \n'); 
disp(datlog.audioCues.start);
datlog.audioCues.start=datlog.audioCues.start(~temp);
if ~isempty(datlog.framenumbers.data)
    datlog.audioCues.startInRelativeTime = (datlog.audioCues.start- datlog.framenumbers.data(1,2))*86400;
    datlog.audioCues.startInDateTime = datetime(datlog.audioCues.start, 'ConvertFrom','datenum');
else
    warning('\nNo frame number available, check did this trial actually start in Vicon?')
end

%convert response time to relative time to vicon frame 1 and add date time format.
%  {'Time','Index','Stimulus','ResponseTime'} 
datlog.response.dataheader{end+1} = 'RelativeTimeToTaskStart';
%don't eliminate data incase some nan rows exist (shouldn't happen)
% temp = isnan(datlog.response.data(:,1)); %time is nan
% datlog.response.data = datlog.response.data(~temp,:);
%add last column as relative time (i don't think we will use this)
%TODO/Improvement: is it needed? we care more about response time since stimulus
%onset
if isempty(datlog.response.data)
    warning('Participant did not press any button in this trial.')
else
    if ~isempty(datlog.framenumbers.data)
        datlog.response.data(:,end+1) = (datlog.response.data(:,1)- datlog.framenumbers.data(1,2))*86400; %relative time, bc it's in array format first convert to mat for numerical operations, then convert back to mat for storage
        datlog.response.inDateTime = datetime(datlog.response.data(:,1), 'ConvertFrom','datenum');
    else
        warning('\nNo frame number available, check did this trial actually start in Vicon?')
    end
end

if recordData
    stop(recObj);
    audioData = getaudiodata(recObj);
    datlog.audioCues.recording{end+1} = audioData;
    datlog.audioCues.recording=datlog.audioCues.recording';
    audiowrite([savename, '_Recording.wav'],audioData, Fz);
    audioinfo([savename, '_Recording.wav'])
end
%Get rid of graphical objects we no longer need:
if exist('ff','var') && isvalid(ff)
    close(ff)
end
set(ghandle.profileaxes,'Color',[1,1,1])
delete(findobj(ghandle.profileaxes,'Type','Text'))
delete(findobj(ghandle.profileaxes,'Type','Patch'))

%Consider delete
%Print some info:
% NR=length(datlog.stepdata.paramRHS);
% NL=length(datlog.stepdata.paramLHS);
% for M=[20,50]
%     i1=max([1 NR-M]);
%     i2=max([1 NL-M]);
%     disp(['Average params for last ' num2str(M) ' strides: '])
%     disp(['R=' num2str(nanmean(datlog.stepdata.paramRHS(i1:end))) ', L=' num2str(nanmean(datlog.stepdata.paramLHS(i2:end)))])
% end

catch ME
    datlog.errormsgs{end+1} = 'Error when converting time. Most likely because there was an error earlier in the main control loop.';
    datlog.errormsgs{end+1} = ME;
    fprintf('\nError when converting time. Most likely because there was an error earlier in the main control loop.\nScroll up to see the error printed in black text, or load the most recent datlog to track call stack.\n')
    ME.getReport
%     disp('Error ocurred during the control loop, see datlog for details...');
end

disp('saving datlog...');
try
    save(savename,'datlog');
    [d,~,~]=fileparts(which(mfilename));
    save([d '\..\datlogs\lastDatlog.mat'],'datlog');
catch ME
    disp(ME);
end
