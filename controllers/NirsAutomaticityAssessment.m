function [RTOTime, LTOTime, RHSTime, LHSTime, commSendTime, commSendFrame] = NirsAutomaticityAssessment(velL,velR,profilename,mode,signList,paramComputeFunc,paramCalibFunc, current_iteration)
%This function takes two vectors of speeds (one for each treadmill belt)
%and succesively updates the belt speed upon ipsilateral Toe-Off
%The function only updates the belts alternatively, i.e., a single belt
%speed cannot be updated twice without the other being updated
%The first value for velL and velR is the initial desired speed, and new
%speeds will be sent for the following N-1 steps, where N is the length of
%velL
%% Parameter for randomization order 
randomization_order = [2 6 5 3 4 1]; %for visit 2, random number between 7 -12
startingAlphabet ='A';

%% Parameters FIXed for this protocol (don't change it unless you know what you are doing)
oxysoft_present = 1; 
restDuration = 20; %default 20s rest and 20s for task, could change for debugging

%% Set up task sequence, recordings and main loop
timeEpsilon = 0.05; %tolerance for time elapsed >= target - epsilon will count as in target window. e.g., if rest is 30s, timePassed >= 29.975 will all be considered acceptable
recordData = false; %usually false now bc of headset problems, could turn off for debugging

if current_iteration == 0
    if strcmp(startingAlphabet, 'A')
        event_list = [3 1 2 4 5]; %do it in fixed order for famirization: walk, stand alpha A, walk alpha, stand 3 A, walk 3A
    else
        event_list = [3 6 7 8 9];%walk, stand alpha B, walk alphaB, stand 3 B, walk 3B
    end
    restDuration = 25;
    recordData = false;
    % Pop up window to confirm parameter setup
    button=questdlg('Please confirm that oxysoft_present is 1 (NIRS connected) and rest duration is 20.');  
    if ~strcmp(button,'Yes')
       return; %Abort starting the tri
    end
else
    if strcmp(startingAlphabet, 'A')
%         all_events = [2 4 3 1 5;4 3 2 1 5;3 1 2 4 5; 3 2 4 5 1;3 4 1 2 5;2 3 5 4 1]; %AUF/AUC Study order
        all_events = [1 5 4 2 3; 1 3 2 5 4; 5 3 1 4 2; 5 1 4 2 3; 4 3 1 5 2; 5 4 2 3 1]; %BrainWalk Order
    else
        %fixed order, only change the order to index these.
%         all_events= [7 8 3 6 9; 8 3 7 6 9; 3 6 7 8 9; 3 7 8 9 6; 3 8 6 7 9; 7 3 9 8 6]; %AUF/AUC Study order
        all_events = [9 3 7 8 6;3 9 6 7 8;9 6 7 8 3;8 6 7 9 3;9 7 8 3 6;7 9 3 8 6]; %BrainWalk order
    end
    event_list = all_events(randomization_order(current_iteration),:);
    %1 = stand and alphabet A, 2 = walk and alphabet A, 3 = walk, 4 = stand and
    %alphabet 3 A, 5 = walk and alphabet 3 A; 6 = stand and alphabet B, 7 = walk and alphabet B, 8 = stand and
    %alphabet 3B, 9 = walk and alphabet 3B
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

global feedbackFlag
if feedbackFlag==1  %&& size(get(0,'MonitorPositions'),1)>1
    ff=figure('Units','Normalized','Position',[1 0 1 1]);
    pp=gca;
    axis([0 length(velL)  0 2]);
    ccc1=animatedline('Parent',pp,'Marker','o','LineStyle','none','MarkerFaceColor',[0 0 1],'MarkerEdgeColor','none');
    ccc2=animatedline('Parent',pp,'Marker','o','LineStyle','none','MarkerFaceColor',[1 0 0],'MarkerEdgeColor','none');    
end

%TODO: to clean up    
paramLHS=0;
paramRHS=0;
lastParamLHS=0;
lastParamRHS=0;
lastRstepCount=0;
lastLstepCount=0;
LANK=zeros(1,6);
RANK=zeros(1,6);
RHIP=zeros(1,6);
LHIP=zeros(1,6);
LANKvar=1e5*ones(6);
RANKvar=1e5*ones(6);
RHIPvar=1e5*ones(6);
LHIPvar=1e5*ones(6);
lastLANK=nan(1,6);
lastRANK=nan(1,6);
lastRHIP=nan(1,6);
lastLHIP=nan(1,6);
toneplayed=false;

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
signCounter=1;

global PAUSE%pause button value
global STOP
global memory
global enableMemory
global firstPress
STOP = false;
fo=4000;
signS=0; %Initialize
endTone=3*sin(2*pi*[1:2048]*fo*.025/4096);  %.5 sec tone at 100Hz, even with noise cancelling this is heard
tone=sin(2*pi*[1:2048]*1.25*fo/4096); %.5 sec tone at 5kHz, even with noise cancelling this is heard

ghandle = guidata(AdaptationGUI);%get handle to the GUI so displayed data can be updated

%Initialize some graphical objects:
ppp1=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','o','MarkerFaceColor',[0.68 .92 1],'MarkerEdgeColor','none');
ppp2=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','o','MarkerFaceColor',[1 .6 .78],'MarkerEdgeColor','none');
ppp3=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[0 0 1]);
ppp4=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[1 0 0]);
ppv1=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[0 .5 1]);
ppv2=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[1 .5 0]);

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
datlog.messages = cell(1,2);
datlog.framenumbers.header = {'frame #','U Time','Relative Time'};
datlog.framenumbers.data = zeros(300*length(velR)+7200,2);
datlog.stepdata.header = {'Step#','U Time','frame #','Relative Time'};
datlog.stepdata.RHSdata = zeros(length(velR)+50,3);%empty cell theoretically big enough to house all the steps taken
datlog.stepdata.RTOdata = zeros(length(velR)+50,3);
datlog.stepdata.LHSdata = zeros(length(velL)+50,3);
datlog.stepdata.LTOdata = zeros(length(velL)+50,3);
datlog.stepdata.paramLHS = zeros(length(velR)+50,1);
datlog.stepdata.paramRHS = zeros(length(velL)+50,1);
datlog.audioCues.start = [];
datlog.audioCues.audio_instruction_message = {};
datlog.audioCues.recording={};
datlog.straightTime = [];
datlog.walkTime = [];
histL=nan(1,50);
histR=nan(1,50);
histCount=1;
filtLHS=0;
filtRHS=0;
datlog.inclineang = [];
datlog.speedprofile.velL = velL;
datlog.speedprofile.velR = velR;
datlog.speedprofile.signListForNullTrials = signList;
datlog.TreadmillCommands.header = {'RBS','LBS','angle','U Time','Relative Time'};
datlog.TreadmillCommands.read = nan(300*length(velR)+7200,4);
datlog.TreadmillCommands.sent = nan(300*length(velR)+7200,4);%nan(length(velR)+50,4);
datlog.Markers.header = {'x','y','z'};
datlog.Markers.LHIP = nan(300*length(velR)+7200,3);
datlog.Markers.RHIP = nan(300*length(velR)+7200,3);
datlog.Markers.LANK = nan(300*length(velR)+7200,3);
datlog.Markers.RANK = nan(300*length(velR)+7200,3);
datlog.Markers.LHIPfilt = nan(300*length(velR)+7200,6);
datlog.Markers.RHIPfilt = nan(300*length(velR)+7200,6);
datlog.Markers.LANKfilt = nan(300*length(velR)+7200,6);
datlog.Markers.RANKfilt = nan(300*length(velR)+7200,6);
datlog.Markers.LHIPvar = nan(300*length(velR)+7200,36);
datlog.Markers.RHIPvar = nan(300*length(velR)+7200,36);
datlog.Markers.LANKvar = nan(300*length(velR)+7200,36);
datlog.Markers.RANKvar = nan(300*length(velR)+7200,36);
datlog.stepdata.paramComputeFunc=func2str(paramComputeFunc);
if mode==4
    datlog.stepdata.paramCalibFunc=func2str(paramCalibFunc);
end

%do initial save
try
    save(savename,'datlog');
catch ME
    disp(ME);
end

%Check that velL and velR are of equal length
N=length(velL)+1;
if length(velL)~=length(velR)
    disp('WARNING, velocity vectors of different length!');
    datlog.messages{end+1,1} = 'Velocity vectors of different length selected';
end
%Adding a fake step at the end to avoid out-of-bounds indexing, but those
%speeds should never get used in reality:
velL(end+1)=0;
velR(end+1)=0;

%Initialize nexus & treadmill communications
try
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
    % Enable some different data types
    out =MyClient.EnableSegmentData();
    out =MyClient.EnableMarkerData();
    out=MyClient.EnableUnlabeledMarkerData();
    out=MyClient.EnableDeviceData();
    
    MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );
    
    
    mn={'LHIP','RHIP','LANK','RANK'};
    altMn={'LGT','RGT','LANK','RANK'};
catch ME
    disp('Error in creating Nexus Client Object/communications see datlog for details');
    datlog.errormsgs{end+1} = 'Error in creating Nexus Client Object/communications';
    datlog.errormsgs{end+1} = ME;%store specific error
    disp(ME);
end
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
    datlog.messages(end+1,:) = {'Nexus and Bertec Interfaces initialized: ', now};
    
    %Initiate variables
    RTOTime(N) = now;
    LTOTime(N) = now;
    RHSTime(N) = now;
    LHSTime(N) = now;
    commSendTime=zeros(2*N-1,6);
    commSendFrame=zeros(2*N-1,1);
    disp('nirs range')
    y_max = 4250;%0 treadmill, max = 4.25meter ~= 13.94 ft = 6-7 tiles
    y_min = -2300;%0 treadmill, min = 2.3meter ~=7.55 ft = 3-4 tiles
%     inout1 = 0; %initialize both variables to 0
%     inout2 = 0;    
    
    LHS_time = 0;
    RHS_time = 0;
    LHS_pos = 0;
    RHS_pos = 0;
    HS_frame = 0;
    pad = 50;
    

    %Connect to Oxysoft
    disp('Initial Setup')
    trialIndex = 1;
    eventorder = event_list(trialIndex,:); %0 = stand and alphabet, 1 = walk and alphabet, 2 = walk, 
    %set up audio players
    audioids = {'standAndA','walkAndA','walk','standAndEvery3A','walkAndEvery3A',...
        'standAndB','walkAndB','standAndEvery3B','walkAndEvery3B','relax','rest','stopAndRest'};
    eventCodeCharacter = {'A','B','W','C','D','E','F','G','H'};
    %1 = stand and alphabet A, 2 = walk and alphabet A, 3 = walk, 4 = stand and
    %alphabet 3 A, 5 = walk and alphabet 3 A; 6 = stand and alphabet B, 7 = walk and alphabet B, 8 = stand and
    %alphabet 3B, 9 = walk and alphabet 3B
    instructions = containers.Map();
    for i = 1 : length(audioids)
%         disp(strcat(audioids{i},'.mp3'))
        [audio_data,audio_fs]=audioread(strcat(audioids{i},'.mp3'));
        instructions(audioids{i}) = audioplayer(audio_data,audio_fs);
    end
    % Write event I with description 'Instructions' to Oxysoft
    datlog = nirsEvent('', 'I', ['Connected',num2str(current_iteration)], instructions, datlog, Oxysoft, oxysoft_present);

    %start with a rest block
    disp('Rest');

    currentIndex = 1;
    nirsRestEventString = generateNirsRestEventString(eventorder, currentIndex);
    datlog = nirsEvent('rest', 'R', nirsRestEventString, instructions, datlog, Oxysoft, oxysoft_present);
    pause(restDuration);
    
    for possibleStandEvent = 1:4 %it's possible all standings are next to each other, in that case loop here untill a walk or DTWalk is coming
        if ismember(eventorder(currentIndex),[1,4,6,8]) %stand and alphabetA or B, or 3 letters A or B
            datlog = nirsEvent(audioids{eventorder(currentIndex)}, eventCodeCharacter{eventorder(currentIndex)}, audioids{eventorder(currentIndex)}, instructions, datlog, Oxysoft, oxysoft_present);
            currentIndex = currentIndex + 1;
            pause(restDuration);

%             %complete follow a rest block
            nirsRestEventString = generateNirsRestEventString(eventorder, currentIndex);
            datlog = nirsEvent('stopAndRest','R',nirsRestEventString, instructions, datlog, Oxysoft, oxysoft_present);
            pause(restDuration);
        end

        if ismember(eventorder(currentIndex),[2,3,5,7,9]) %first event is walk and alphabet
            datlog = nirsEvent(audioids{eventorder(currentIndex)},eventCodeCharacter{eventorder(currentIndex)},audioids{eventorder(currentIndex)}, instructions, datlog, Oxysoft, oxysoft_present);
            tStart=clock;
            currentIndex  = currentIndex + 1;
            break; %repeat untill a walk task is detected %TODO: check this actually breaks out
        end
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
            datlog.messages(end+1,:) = {'Loop paused at ', now};
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
    
        if framenum.Value~= datlog.framenumbers.data(frameind.Value,1) %Frame num value changed, reading data
            frameind.Value = frameind.Value+1; %Frame counter
            datlog.framenumbers.data(frameind.Value,:) = [framenum.Value now];
                        
            %Read markers:
            sn=MyClient.GetSubjectName(0).SubjectName;
            l=1;
            md=MyClient.GetMarkerGlobalTranslation(sn,mn{l});

            md_LHIP=MyClient.GetMarkerGlobalTranslation(sn,altMn{1});
            md_RHIP=MyClient.GetMarkerGlobalTranslation(sn,altMn{2});
            md_LANK=MyClient.GetMarkerGlobalTranslation(sn,mn{3});
            md_RANK=MyClient.GetMarkerGlobalTranslation(sn,mn{4});

            if strcmp(md.Result,'Success') %md.Result.Value==2 %%Success getting marker
                aux=double(md.Translation);


                LHIP_pos = double(md_LHIP.Translation);
                RHIP_pos = double(md_RHIP.Translation);
                LANK_pos = double(md_LANK.Translation);
                RANK_pos = double(md_RANK.Translation);
            else
                md=MyClient.GetMarkerGlobalTranslation(sn,altMn{l});
                if strcmp(md.Result,'Success') % md.Result.Value==2
                    aux=double(md.Translation);
                    LHIP_pos = double(md_LHIP.Translation);
                    RHIP_pos = double(md_RHIP.Translation);
                    LANK_pos = double(md_LANK.Translation);
                    RANK_pos = double(md_RANK.Translation);
                else
                    aux=[nan nan nan]';
                    LHIP_pos = [nan nan nan]';
                    RHIP_pos = [nan nan nan]';
                    LANK_pos = [nan nan nan]';
                    RANK_pos = [nan nan nan]';
                end
                if all(aux==0) || all(LHIP_pos==0) || all(RHIP_pos==0) || all(LANK_pos==0) || all(RANK_pos==0)
                    %Nexus returns 'Success' values even when marker is missing, and assigns it to origin!
                    %warning(['Nexus is returning origin for marker position of ' mn{l}]) %This shouldn't happen
                    aux=[nan nan nan]';
                    LHIP_pos = [nan nan nan]';
                    RHIP_pos = [nan nan nan]';
                    LANK_pos = [nan nan nan]';
                    RANK_pos = [nan nan nan]';
                end
            end
            %aux
            %Here we should implement some Kalman-like filter:
            %eval(['v' mn(l) '=.8*v' mn(l) '+ (aux-' mn(l) ');']);
            eval(['lastEstimate=' mn{l} ''';']); %Saving previous estimate
            eval(['last' mn{l} '=lastEstimate'';']); %Saving previous estimate as row vec
            eval(['lastEstimateCovar=' mn{l} 'var;']); %Saving previous estimate's variance
            eval(['datlog.Markers.' mn{l} '(frameind.Value,:) = aux;']);%record the current read

            elapsedFramesSinceLastRead=framenum.Value-datlog.framenumbers.data(frameind.Value-1,1);
            %What follows assumes a 100Hz sampling rate
            n=elapsedFramesSinceLastRead;
            if n<0
                error('inconsistent frame numbering')
            end
                
                
            %% added by Yashar to count steps OG and for verbal feedback action

            set(ghandle.text25,'String',num2str(framenum.Value/100));
            body_y_pos(frameind.Value) = (LHIP_pos(2)+RHIP_pos(2))/2;
            body_y_pos_diff(frameind.Value) = body_y_pos(frameind.Value) - body_y_pos(frameind.Value-1);
            Ank_diff(frameind.Value) = LANK_pos(2) - RANK_pos(2);
            Ank_diffdiff(frameind.Value) = Ank_diff(frameind.Value)-Ank_diff(frameind.Value-1);

            if body_y_pos(frameind.Value) > y_min && body_y_pos(frameind.Value) < y_max && framenum.Value-HS_frame>pad

                if body_y_pos_diff(frameind.Value) >= 0 && Ank_diffdiff(frameind.Value) >= 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1)) 
                    Left_HS(frameind.Value) = 1;
                    sumiL = sum(Left_HS);
                    HS_frame = framenum.Value;
                    LHS_time = [LHS_time framenum.Value/100];
                    LHS_pos = [LHS_pos body_y_pos(frameind.Value)/1000];
                    OG_speed_left = (LHS_pos(end)-LHS_pos(end-1))/(LHS_time(end)-LHS_time(end-1));

                    set(ghandle.LBeltSpeed_textbox,'String',num2str(OG_speed_left));
                    set(ghandle.Left_step_textbox,'String',num2str(sumiL));

                    addpoints(ppp3,sumiL,OG_speed_left)
                    %addpoints(ppv1,sumiL,sumiL/1000)%paramCalibFunc(paramLHS)/1000)

                elseif body_y_pos_diff(frameind.Value) >= 0 && Ank_diffdiff(frameind.Value) < 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
                    Right_HS(frameind.Value) = 1;
                    sumiR = sum(Right_HS);
                    HS_frame = framenum.Value;
                    RHS_time = [RHS_time framenum.Value/100];
                    RHS_pos = [RHS_pos body_y_pos(frameind.Value)/1000];
                    OG_speed_right = (RHS_pos(end)-RHS_pos(end-1))/(RHS_time(end)-RHS_time(end-1));

                    set(ghandle.RBeltSpeed_textbox,'String',num2str(OG_speed_right));
                    set(ghandle.Right_step_textbox,'String',num2str(sumiR))

                    addpoints(ppp4,sumiR,OG_speed_right);
                    %addpoints(ppv2,sumiR,sumiR/1000)%paramCalibFunc(paramRHS)/1000)

                elseif body_y_pos_diff(frameind.Value) < 0 && Ank_diffdiff(frameind.Value) >= 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
                    Right_HS(frameind.Value) = 1;
                    sumiR = sum(Right_HS);
                    HS_frame = framenum.Value;
                    RHS_time = [RHS_time framenum.Value/100];
                    RHS_pos = [RHS_pos body_y_pos(frameind.Value)/1000];
                    OG_speed_right = abs((RHS_pos(end)-RHS_pos(end-1))/(RHS_time(end)-RHS_time(end-1)));

                    set(ghandle.RBeltSpeed_textbox,'String',num2str(OG_speed_right));
                    set(ghandle.Right_step_textbox,'String',num2str(sumiR))

                    addpoints(ppp4,sumiR,OG_speed_right)

                elseif body_y_pos_diff(frameind.Value) < 0 && Ank_diffdiff(frameind.Value) < 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
                    Left_HS(frameind.Value) = 1;
                    sumiL = sum(Left_HS);
                    HS_frame = framenum.Value;
                    LHS_time = [LHS_time framenum.Value/100];
                    LHS_pos = [LHS_pos body_y_pos(frameind.Value)/1000];
                    OG_speed_left = abs((LHS_pos(end)-LHS_pos(end-1))/(LHS_time(end)-LHS_time(end-1)));

                    set(ghandle.LBeltSpeed_textbox,'String',num2str(OG_speed_left));
                    set(ghandle.Left_step_textbox,'String',num2str(sumiL));

                    addpoints(ppp3,sumiL,OG_speed_left)
                end
                    
            elseif body_y_pos(frameind.Value) <= y_min
                %reach one end (computer side)
%                 t1(end+1,:) = clock;
%                 inout1 = 1;
%                 disp('Reaching t1')
            elseif body_y_pos(frameind.Value) >= y_max
                %reach the door side
%                 t2 = clock;
%                 disp('Reaching t2')
%                 inout2 = 1;
%                 inout1 = 0; %half of a loop done, reset the computer side flag untill back in computer side again (complete the loop)
            end
            
            tEnd = clock;
            t_diff = tEnd - tStart;
            t_diff = abs((t_diff(4)*3600)+(t_diff(5)*60)+t_diff(6)); %in seconds
            if  t_diff >= restDuration-timeEpsilon %round(t_diff) == restDuration %%In AUF/AUC: used round in case couldn't get exactly 20s, so will
                %stop from 19.5 ~ 20.49 seconds
                %can be more accurate, and stop after 20-epsilon has
                %passed. Use >= to check one side passing only incase the
                %loop rate is slow and couldn't stay within rest +-
                %timeEpsilon window, so will be more lenient towards extra
                %time.
                fprintf('time diff: %f',t_diff)
                
                %but we can more accurate
                %always stop once, only stop at the computer side, then move on to next instruction.
%                 inout1 = 0; %reset
%                 inout2 = 0;
%                 t1 = [];
                nirsRestEventString = generateNirsRestEventString(eventorder, currentIndex);
                datlog = nirsEvent('stopAndRest','R',nirsRestEventString, instructions, datlog, Oxysoft, oxysoft_present);
                pause(restDuration);

                if currentIndex > length (eventorder)
                    currentIndex = 1; %reset the current index
                    trialIndex = trialIndex + 1;
                    if (trialIndex >  size(event_list,1))
                        STOP = 1;
                        datlog = nirsEvent('relax','O','Trial_End', instructions, datlog, Oxysoft, oxysoft_present);
                    else  %Restart a trial, currently should never be here
                        warning('Check your code. Should not be in this code block.');
                    end
                end
                for possibleStandEvent = 1:4
                    if STOP ~= 1&& ismember(eventorder(currentIndex),[1,4,6,8]) %stand and alphabetA or B, or 3 letters A or B
                        datlog = nirsEvent(audioids{eventorder(currentIndex)},eventCodeCharacter{eventorder(currentIndex)},audioids{eventorder(currentIndex)}, instructions, datlog, Oxysoft, oxysoft_present);
                        currentIndex = currentIndex + 1;
                        pause(restDuration)

                        %complete follow a rest block
                        nirsRestEventString = generateNirsRestEventString(eventorder, currentIndex);
                        datlog = nirsEvent('stopAndRest','R',nirsRestEventString, instructions, datlog, Oxysoft, oxysoft_present);
                        pause(restDuration);

                        if currentIndex > length (eventorder)
                            currentIndex = 1; %reset the current index
                            trialIndex = trialIndex + 1;
                            if (trialIndex >  size(event_list,1))
                                STOP = 1;
                                datlog = nirsEvent('relax','O','Trial_End', instructions, datlog, Oxysoft, oxysoft_present); 
                                break;
                            else %Should never be here
                                warning('Check your code. Should not be in this code block.');
                            end      
                        end 
                    end

                    if STOP ~= 1 && ismember(eventorder(currentIndex),[2,3,5,7,9]) %first event is walk and alphabet
                        datlog = nirsEvent(audioids{eventorder(currentIndex)},eventCodeCharacter{eventorder(currentIndex)},audioids{eventorder(currentIndex)}, instructions, datlog, Oxysoft, oxysoft_present);
                        tStart=clock;
                        currentIndex  = currentIndex + 1;
                        break;
                    end
                end
            end                        
        end
    end %While, when STOP button is pressed
    if STOP
        datlog.messages(end+1,:) = {'Stop button pressed at: ', now};
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

disp('converting time in datlog...');
%convert time data into clock format then re-save
datlog.buildtime = datestr(datlog.buildtime);

%convert frame times & markers
temp = find(datlog.framenumbers.data(:,1)==0,1,'first');
datlog.framenumbers.data(temp:end,:) = [];
for z = 1:temp-1
    datlog.framenumbers.data(z,3) = etime(datevec(datlog.framenumbers.data(z,2)),datevec(datlog.framenumbers.data(1,2)));
end

%convert RHS times
temp = find(datlog.stepdata.RHSdata(:,1) == 0,1,'first');
datlog.stepdata.RHSdata(temp:end,:) = [];
datlog.stepdata.paramRHS(temp:end,:) = [];
for z = 1:temp-1
    datlog.stepdata.RHSdata(z,4) = etime(datevec(datlog.stepdata.RHSdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
end
%convert LHS times
temp = find(datlog.stepdata.LHSdata(:,1) == 0,1,'first');
datlog.stepdata.LHSdata(temp:end,:) = [];
datlog.stepdata.paramLHS(temp:end,:) = [];
for z = 1:temp-1
    datlog.stepdata.LHSdata(z,4) = etime(datevec(datlog.stepdata.LHSdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
end
%convert RTO times
temp = find(datlog.stepdata.RTOdata(:,1) == 0,1,'first');
datlog.stepdata.RTOdata(temp:end,:) = [];
for z = 1:temp-1
    datlog.stepdata.RTOdata(z,4) = etime(datevec(datlog.stepdata.RTOdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
end
%convert LTO times
temp = find(datlog.stepdata.LTOdata(:,1) == 0,1,'first');
datlog.stepdata.LTOdata(temp:end,:) = [];
for z = 1:temp-1
    datlog.stepdata.LTOdata(z,4) = etime(datevec(datlog.stepdata.LTOdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
end

%convert audio times
datlog.audioCues.start = datlog.audioCues.start';
datlog.audioCues.audio_instruction_message = datlog.audioCues.audio_instruction_message';
datlog.straightTime = datlog.straightTime';
% datlog.walkTime = datlog.walkTime';
temp = isnan(datlog.audioCues.start);
disp('\nConverting datalog, current starts \n'); 
disp(datlog.audioCues.start);
datlog.audioCues.start=datlog.audioCues.start(~temp);
datlog.audioCues.startInRelativeTime = (datlog.audioCues.start- datlog.framenumbers.data(1,2))*86400;
datlog.audioCues.startInDateTime = datetime(datlog.audioCues.start, 'ConvertFrom','datenum');

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

%Print some info:
NR=length(datlog.stepdata.paramRHS);
NL=length(datlog.stepdata.paramLHS);
for M=[20,50]
    i1=max([1 NR-M]);
    i2=max([1 NL-M]);
    disp(['Average params for last ' num2str(M) ' strides: '])
    disp(['R=' num2str(nanmean(datlog.stepdata.paramRHS(i1:end))) ', L=' num2str(nanmean(datlog.stepdata.paramLHS(i2:end)))])
end

disp('saving datlog...');
try
    save(savename,'datlog');
    [d,~,~]=fileparts(which(mfilename));
    save([d '\..\datlogs\lastDatlog.mat'],'datlog');
catch ME
    disp(ME);
end
