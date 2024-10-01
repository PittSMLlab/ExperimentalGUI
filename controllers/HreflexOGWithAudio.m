function [RTOTime, LTOTime, RHSTime, LHSTime, commSendTime, commSendFrame] = HreflexOGWithAudio(velL,velR,~,profilename,mode,signList,paramComputeFunc,paramCalibFunc,giveFeedback, hreflex_present)
%This function takes two vectors of speeds and assume velL and velR will be the same throughout the whole trial
%Then computes the desired target time to walk the 7m walkway within the
%speed range of [0.9*velL, 1.1*velL] (i.e., +-10% of velL). When
%participant's speed recorded live is within this window, they will hear
%audio feedback "Good Job". Otherwise they will hear "Too Fast" or "Too
%Slow". Audio feedback is always played at each end of the walkway.
% suppressed input was 'FzThreshold' which is not relevant here
% TODO: consider making the ankle marker difference threshold an input

%Args:
% - hreflex_present: OPTIONAL, default true. Boolean flag indicating if
%                       Hreflex stim should be sent

%% Set up parameter to communicate with the Arduino (for H-reflex)
if nargin < 10 %no param given for if hreflex stim should be delivered, default to true.
    % This parameter should ONLY BE CHANGED IF YOU KNOW WHAT YOU ARE DOING.
    hreflex_present = true; % default true, unless debugging w/out stimulators
end
% default threshold
threshAnkDiffZ = 50;    % 50 mm difference in ankle markers z-axis

%FIXME: If getting stimulated too much, turn this block on.
%                     canStimR = true;
%                     canStimL = true;


%% Open the port to talk to Arduino
if hreflex_present      % if electrically stimulating for H-reflexes, ...
    % assume Arduino on COM4 with baud rate of 600, which is plenty since
    % MATLAB loop rate is the limiting factor
    arduinoPort = serial('COM4','BAUD',600);
    fprintf('Opening ArduinoPort');
    % if this doesn't work b/c port is busy, check that all Arduino ...
    % softwares are closed.
    fopen(arduinoPort);
    fprintf('Done Opening ArduinoPort');
        
    stimInterval = 10; % stimulate every 10 strides (based on kinematics)
    canStim = false; %initialize so that later the code won't complain even if there is no stimulator.
    % tic;                % for the timeSinceLastStim variable
    %     durSSL = zeros(2,1);    % two left single stance durations
    %     durSSR = zeros(2,1);    % two right single stance durations
    %     stimDelayL = now; %in units of now
    %     stimDelayR = now;
    epsilon = 50; % current: 50 = +/- 2.5cm, previous: 100 = +-5cm from perfect hip and ankle alignment (i.e,. hipy - ankley = 0)
    
    %     %Hreflex Alt Sol. find time from HS to midstance based on interpolation function from Omar
    %     %in young healthy participant. If it's older adutls or clinical
    %     %populations, this need to be changed.
    %     stimDelayL = ((-73.8 * velL/1000) + 384.4)/1000;%output should be in in sec, velL/R is in mm/s, fcn needs m/s
    %     stimDelayR = ((-73.8 * velR/1000) + 384.4)/1000;%in sec
end
%%

global feedbackFlag
if feedbackFlag==1  %&& size(get(0,'MonitorPositions'),1)>1
    ff=figure('Units','Normalized','Position',[1 0 1 1]);
    pp=gca;
    axis([0 length(velL)  0 2]);
    animatedline('Parent',pp,'Marker','o','LineStyle','none','MarkerFaceColor',[0 0 1],'MarkerEdgeColor','none');
    animatedline('Parent',pp,'Marker','o','LineStyle','none','MarkerFaceColor',[1 0 0],'MarkerEdgeColor','none');
end

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

if nargin < 9 || isempty(giveFeedback)
    giveFeedback = true; %default true
end

if nargin<5 || isempty(mode)
    error('Need to specify control mode')
end
if nargin<6
    %disp('no sign list')
    signList=[];
end
% signCounter=1;

global PAUSE % pause button value
global STOP
% global memory
% global enableMemory
% global firstPress
STOP = false;
% fo=4000;
% signS=0; %Initialize
% endTone=3*sin(2*pi*[1:2048]*fo*.025/4096);  %.5 sec tone at 100Hz, even with noise cancelling this is heard
% tone=sin(2*pi*[1:2048]*1.25*fo/4096); %.5 sec tone at 5kHz, even with noise cancelling this is heard

% get handle to the GUI so displayed data can be updated
ghandle = guidata(AdaptationGUI);

% initialize some graphical objects
animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','o','MarkerFaceColor',[0.68 .92 1],'MarkerEdgeColor','none');
animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','o','MarkerFaceColor',[1 .6 .78],'MarkerEdgeColor','none');
ppp3=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[0 0 1]);
ppp4=animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[1 0 0]);
animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[0 .5 1]);
animatedline('Parent',ghandle.profileaxes,'LineStyle','none','Marker','.','Color',[1 .5 0]);

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
    text(iL(i),yl(1)+.05*diff(yl),num2str(auxT),'Color',[0 0 1]);
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
    text(iL(i),yl(1)+.1*diff(yl),num2str(auxT),'Color',[1 0 0]);
end

%% initialize a data structure that saves information about the trial

datlog = struct();
datlog.buildtime = now; % timestamp
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
% TODO: what are the below two (i.e., paramLHS ...)? not in other cntrlr
datlog.stepdata.paramLHS = zeros(length(velR)+50,1);
datlog.stepdata.paramRHS = zeros(length(velL)+50,1);
datlog.walkTime = [];
% histL=nan(1,50);
% histR=nan(1,50);
% histCount=1;
% filtLHS=0;
% filtRHS=0;
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
datlog.OGspeed.header = {'RStep#','Time','Frame#','Performance'};
datlog.OGspeed.labels = {'Fast: +1', 'Good: 0', 'Slow: -1'};
datlog.OGspeed.Performance = []; % nan(length(velR)+50,4); % this should be initialized as empty
datlog.stim.header = {'Step#','HipAnklePosDiff','HipPos','AnklePos'};
datlog.stim.L = [];
datlog.stim.R = [];

if mode==4
    datlog.stepdata.paramCalibFunc=func2str(paramCalibFunc);
end

% do initial save
try
    save(savename,'datlog');
catch ME
    disp(ME);
end

% check that velL and velR are of equal length
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
    % the below code was added by DMMO
    HostName = 'localhost:801';
    % fprintf( 'Loading SDK...' );
    addpath( '..\dotNET' );
    dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
    if dssdkAssembly == ""
        [ file, path ] = uigetfile( '*.dll' );
        dssdkAssembly = fullfile( path, file );
    end
    
    NET.addAssembly(dssdkAssembly);
    MyClient = ViconDataStreamSDK.DotNET.Client();
    MyClient.Connect(HostName);
    % Enable some different data types
    MyClient.EnableMarkerData();
    MyClient.EnableDeviceData();
    MyClient.SetStreamMode(ViconDataStreamSDK.DotNET.StreamMode.ClientPull);
    
    mn={'LHIP','RHIP','LANK','RANK','LHEEL','RHEEL','LTOE','RTOE'};
    altMn={'LGT','RGT','LANK','RANK','LHEEL','RHEEL','LTOE','RTOE'};
catch ME
    disp('Error in creating Nexus Client Object/communications see datlog for details');
    datlog.errormsgs{end+1} = 'Error in creating Nexus Client Object/communications';
    datlog.errormsgs{end+1} = ME;%store specific error
    disp(ME);
end

try % so that if something fails, communications are closed properly
    MyClient.GetFrame();
    datlog.messages(end+1,:) = {'Nexus and Bertec Interfaces initialized: ', now};
    
    % initiate variables
    % new_stanceL = false; % from previous version that detected stance
    % new_stanceR = false;
    isCurrSwingL = false;
    isCurrSwingR = false;
    % 0 = Double Support, 1 = single L support, 2 = single R support
    phase = 0;
    LstepCount=1;
    RstepCount=1;
    RTOTime(N) = now;
    LTOTime(N) = now;
    RHSTime(N) = now;
    LHSTime(N) = now;
    RTOTime2(N) = 0;    % second time array based on frame number
    LTOTime2(N) = 0;
    RHSTime2(N) = 0;
    LHSTime2(N) = 0;
    RTOPos = nan(N,1);
    LTOPos = nan(N,1);
    RHSPos = nan(N,1);
    LHSPos = nan(N,1);
    numSamples = 10;    % number of points to store in marker data buffers
    LHEELz = nan(numSamples,1);
    RHEELz = nan(numSamples,1);
    LTOEz = nan(numSamples,1);
    RTOEz = nan(numSamples,1);
    commSendTime=zeros(2*N-1,6);
    commSendFrame=zeros(2*N-1,1);
    % stepFlag=0;
    
    % 7 meters / speed in m/s, fastest and slowest are specified in terms of time required to walk between y_min and y_max
    % fastest should have the smaller number because it is time
    fastest = 7/(velL(1)/1000*1.1); % assume same speeds throughout, compute time using first stride (i.e., index 1) speed value
    slowest = 7/(velL(1)/1000*0.9); % assume same speeds throughout, compute time using index 1.
    
    % TODO: I am getting that the start of the tile with the yellow tape
    % (i.e., the tape that indicates the end of the OG walkway) is at
    % ~5001. Why is the max set at 4500? Because these are the bounds at
    % which step counting no longer occurs and audio feedback can be given
    y_max = 4500;
    % TODO: I am getting that the start of the tile with the yellow tape is
    % at ~-2976. Why is the min set at -2500?
    y_min = -2500;
    
    canGiveFdbkN = false;   % initialize to false
    canGiveFdbkS = false;
    
    if giveFeedback
        audioids = {'fast','good','slow'};
        instructions = containers.Map();
        for i = 1 : length(audioids)
            [audio_data,audio_fs]=audioread(strcat(audioids{i},'.mp3'));
            instructions(audioids{i}) = audioplayer(audio_data,audio_fs);
        end
    end
    % send first speed command & store
    commSendTime(1,:) = clock;
    
    %% Main loop
    
    old_velR = libpointer('doublePtr',velR(1));
    old_velL = libpointer('doublePtr',velL(1));
    frameind = libpointer('doublePtr',1);
    framenum = libpointer('doublePtr',0);
    
    %Get first frame
    MyClient.GetFrame();
    framenum.Value = MyClient.GetFrameNumber().FrameNumber;
    datlog.framenumbers.data(frameind.Value,:) = [framenum.Value now];
    
    while ~STOP % only runs if stop button is not pressed
        % TODO: delete 'pause' if not necessary since not in other cntrlr
        pause(.001) %This ms pause is required to allow Matlab to process callbacks from the GUI.
        %It actually takes ~2ms, as Matlab seems to be incapable of pausing for less than that (overhead of the pause() function, I presume)
        while PAUSE % only runs if pause button is pressed
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
        
        % TODO: what is this 'drawnow' doing in the other cntrlr?
        % drawnow;
        % update previous iteration stance value
        % TODO: consider updating to curr and prev swing rather than stance
        % old_stanceL = new_stanceL;
        % old_stanceR = new_stanceR;
        isPrevSwingL = isCurrSwingL;
        isPrevSwingR = isCurrSwingR;
        
        %Read frame, update necessary structures
        MyClient.GetFrame();
        framenum.Value = MyClient.GetFrameNumber().FrameNumber;
        
        if framenum.Value~= datlog.framenumbers.data(frameind.Value,1) %Frame num value changed, reading data
            frameind.Value = frameind.Value+1; %Frame counter
            datlog.framenumbers.data(frameind.Value,:) = [framenum.Value now];
            
            %Read markers:
            sn=MyClient.GetSubjectName(0).SubjectName;
            l=1;
            md=MyClient.GetMarkerGlobalTranslation(sn,mn{l});
            
            % TODO: remove markers that are not used in the state machine
            % logic to avoid slowing down the loop
            md_LHIP=MyClient.GetMarkerGlobalTranslation(sn,altMn{1});
            md_RHIP=MyClient.GetMarkerGlobalTranslation(sn,altMn{2});
            md_LANK=MyClient.GetMarkerGlobalTranslation(sn,mn{3});
            md_RANK=MyClient.GetMarkerGlobalTranslation(sn,mn{4});
            md_LHEEL = MyClient.GetMarkerGlobalTranslation(sn,mn{5});
            md_RHEEL = MyClient.GetMarkerGlobalTranslation(sn,mn{6});
            md_LTOE = MyClient.GetMarkerGlobalTranslation(sn,mn{7});
            md_RTOE = MyClient.GetMarkerGlobalTranslation(sn,mn{8});
            
            %md.Result.Value==2 %DMMO %%Success getting marker
            % if successfully got markers, ...
            if strcmp(md.Result,'Success')
                aux=double(md.Translation);
                
                % retrieve the 3D coordinates of each marker
                LHIP_pos = double(md_LHIP.Translation);
                RHIP_pos = double(md_RHIP.Translation);
                LANK_pos = double(md_LANK.Translation);
                RANK_pos = double(md_RANK.Translation);
                LHEEL_pos = double(md_LHEEL.Translation);
                RHEEL_pos = double(md_RHEEL.Translation);
                LTOE_pos = double(md_LTOE.Translation);
                RTOE_pos = double(md_RTOE.Translation);
            else    % otherwise, ...
                % try again with the alternate marker names
                md=MyClient.GetMarkerGlobalTranslation(sn,altMn{l});
                if strcmp(md.Result,'Success')% md.Result.Value==2 %DMMO
                    aux=double(md.Translation);
                    LHIP_pos = double(md_LHIP.Translation);
                    RHIP_pos = double(md_RHIP.Translation);
                    LANK_pos = double(md_LANK.Translation);
                    RANK_pos = double(md_RANK.Translation);
                    LHEEL_pos = double(md_LHEEL.Translation);
                    RHEEL_pos = double(md_RHEEL.Translation);
                    LTOE_pos = double(md_LTOE.Translation);
                    RTOE_pos = double(md_RTOE.Translation);
                else
                    aux=[nan nan nan]';
                    LHIP_pos = [nan nan nan]';
                    RHIP_pos = [nan nan nan]';
                    LANK_pos = [nan nan nan]';
                    RANK_pos = [nan nan nan]';
                    LHEEL_pos = [nan nan nan]';
                    RHEEL_pos = [nan nan nan]';
                    LTOE_pos = [nan nan nan]';
                    RTOE_pos = [nan nan nan]';
                end
                if all(aux==0) || all(LHIP_pos==0) || all(RHIP_pos==0) || all(LANK_pos==0) || all(RANK_pos==0) || all(LHEEL_pos==0) || all(RHEEL_pos==0) || all(LTOE_pos==0) || all(RTOE_pos==0)
                    %Nexus returns 'Success' values even when marker is missing, and assigns it to origin!
                    %warning(['Nexus is returning origin for marker position of ' mn{l}]) %This shouldn't happen
                    aux=[nan nan nan]';
                    LHIP_pos = [nan nan nan]';
                    RHIP_pos = [nan nan nan]';
                    LANK_pos = [nan nan nan]';
                    RANK_pos = [nan nan nan]';
                    LHEEL_pos = [nan nan nan]';
                    RHEEL_pos = [nan nan nan]';
                    LTOE_pos = [nan nan nan]';
                    RTOE_pos = [nan nan nan]';
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
            
            %% Gait Event Detection State Machine based on FP GED logic (NWB)
            
            rateFrame = 100; % assuming 100 Hz frame rate
            set(ghandle.text25,'String',num2str(framenum.Value/rateFrame));
            % y-axis position of the body estimated as the average of the
            % y-axis position of the greater trochanter markers
            % TODO: may need to store previous value to determine direction
            % of travel
            posBodyY = (LHIP_pos(2) + RHIP_pos(2)) / 2;
            
            % Here assuming that the z-axis component of the foot markers
            % always reach their minimum in order of HEEL, ANK, TOE (i.e.,
            % heel strike then flat foot then toe off, rolling the foot
            % over the ground with each new step) with the trough of HEEL
            % corresponding to just after heel strike and the trough of TOE
            % corresponding to just before toe off
            % NOTE: this assumption does not hold when marching in place
            % (i.e., touching the toe down first then the heel) or when
            % walking with a forefoot strike (i.e., tippy toeing across the
            % floor)
            % TODO: implement logic to handle first step (initial double
            % stance need to search for toe off event)
            % TODO: implement logic to handle the turns (e.g., stopping
            % gait event detection and stride counting once pass some
            % y-axis threshold and resume first gait event detection once
            % within bounds again)
            % TODO: add code to update the GUI and stop the trial recording
            % once reach the correct number of strides
            % TODO: add audio feedback to progress to the end of a walkway
            % when hit the correct number of strides
            
            % first update the marker data buffers
            % TODO: is 10 a good data buffer size?
            % shift previous data back by one in the array
            LHEELz(1:end-1) = LHEELz(2:end);
            RHEELz(1:end-1) = RHEELz(2:end);
            LTOEz(1:end-1) = LTOEz(2:end);
            RTOEz(1:end-1) = RTOEz(2:end);
            % add the latest sample to the end of the array
            LHEELz(end) = LHEEL_pos(3); % z-axis LHEEL marker component
            RHEELz(end) = RHEEL_pos(3); % z-axis RHEEL marker component
            LTOEz(end) = LTOE_pos(3); % z-axis LTOE marker component
            RTOEz(end) = RTOE_pos(3); % z-axis RTOE marker component
            LANKz = LANK_pos(3);        % z-axis LANK marker component
            RANKz = RANK_pos(3);        % z-axis RANK marker component
            AnkDiffZ = LANKz - RANKz;   % height difference between ankles
            % TODO: would this be more robust if corroborated swing with
            % the z-axis difference of the TOE or HEEL markers?
            
            % find index of minimum value in marker data buffer
            % NOTE: there is a small dip in HEEL z value just before full
            % heel strike (presumably the heel skidding on ground before
            % pressing in as heel strikes and if this value is ever a
            % trough will falsely detect heel strike
            [~,indLHz] = min(LHEELz);
            [~,indRHz] = min(RHEELz);
            [~,indLTz] = min(LTOEz);
            [~,indRTz] = min(RTOEz);
            % TODO: do we need to add a check to ensure that the trough is
            % sufficiently lower than the edges (e.g., all values at start
            % of function will be zero and then all will stay low when
            % filling up the buffer with standing values)?
            
            % NOTE: the trough is just after heel strike so do not want too
            % many extra new points in buffer after the trough before
            % detecting heel strike (perhaps trough between samples 5 - 8)
            
            % if trough is detected in the heel marker data, new stance
            % previously >= (numSamples/2) to try to catch trough earlier
            % trough between sample 3 and 8 inclusive
            % NWB 04/08/2024: updated to be between 4 and 7 inclusive
            %             new_stanceL = (indLHz <= (numSamples - 3)) && (indLHz > 3);
            %             new_stanceR = (indRHz <= (numSamples - 3)) && (indRHz > 3);
            % TODO: store buffer of ankle difference data and dynamically
            % update threshold based on first few strides
            % TODO: test play back with all C3 participants to ensure
            % functioning properly
            
            % if positive ankle height difference greater than threshold
            % indicating left leg in swing phase
            isCurrSwingL = AnkDiffZ > threshAnkDiffZ;
            % if negative ankle height difference less than negative
            % threshold indicating right leg in swign phase
            isCurrSwingR = AnkDiffZ < -threshAnkDiffZ;
            
            % TODO: do we need ANK or TOE markers at all with this
            % algorithm (e.g., to corroborate toe off events)?
            %             LHS =  new_stanceL && ~old_stanceL;
            %             RHS =  new_stanceR && ~old_stanceR;
            LHS = ~isCurrSwingL &&  isPrevSwingL;
            RHS = ~isCurrSwingR &&  isPrevSwingR;
            
            % TODO: using the 'new_stance' and 'old_stance' booleans only
            % makes sense in the context of using threshold-based force
            % plate algorithm where stance is detected
            % LTO = ~new_stanceL &&  old_stanceL;
            % RTO = ~new_stanceR &&  old_stanceR;
            % if trough is detected in the toe marker data (between samples
            % 3 and 5 inclusive, i.e., after time has passed to account for
            % toe off occuring just after trough), new toe off event
            % TODO: May be better to define gait event state machine based
            % on swing and use the difference between the right and left
            % foot markers z-axis components to distinguish between swing
            % and stance
            % previously <= (numSamples/2) to try to identify trough later
            % trough between samples 3 and 8 inclusive
            % NWB 04/08/2024: updated to be between 4 and 7 inclusive
            %             LTO = (indLTz <= (numSamples - 3)) && (indLTz > 3);
            %             RTO = (indRTz <= (numSamples - 3)) && (indRTz > 3);
            LTO =  isCurrSwingL && ~isPrevSwingL;
            RTO =  isCurrSwingR && ~isPrevSwingR;
            
            % if current position is within the bounds of the walkway
            % (i.e., not a turn at the end of the walkway), ...
            if (posBodyY > y_min) && (posBodyY < y_max)
                % gait event detection state machine: 0 = initial double stance
                % phase only, 1 = single stance left leg, 2 = single stance
                % right leg, 3 = double stance from left single stance, 4 =
                % double stance from right single stance
                % TODO: maybe state machine should always run even during
                % turns to update phase as best as possible but step count
                % should only be incremented and stim enabled within the
                % bounds? Need to handle keeping track of gait event during
                % when re-entering straight away bounds
                % TODO: need to ensure that one leg is not stimulated at
                % the end of the walkway and the other after the turn
                switch phase    % logic depending on current gait phase
                    case 0      % double stance, initial phase only
                        if RTO  % if right toe off event detected, ...
                            phase = 1;    % progress to single stance left
                            RstepCount = RstepCount + 1;    % increment step count
                            RTOTime(RstepCount) = now;
                            RTOTime2(RstepCount) = framenum.Value / rateFrame;
                            RTOPos(RstepCount) = posBodyY;
                            % update step count GUI textboxes
                            set(ghandle.Right_step_textbox,'String',num2str(RstepCount-1));
                            datlog.stepdata.RTOdata(RstepCount-1,:) = [RstepCount-1,now,framenum.Value];
                        elseif LTO  % if left toe off event detected, ...
                            phase = 2;    % progress to single stance right
                            LstepCount = LstepCount + 1;    % increment step count
                            LTOTime(LstepCount) = now;
                            LTOTime2(LstepCount) = framenum.Value / rateFrame;
                            LTOPos(LstepCount) = posBodyY;
                            % update step count GUI textboxes
                            set(ghandle.Left_step_textbox,'String',num2str(LstepCount-1));
                            datlog.stepdata.LTOdata(LstepCount-1,:) = [LstepCount-1,now,framenum.Value];
                        end
                    case 1      % single stance left leg
                        if RHS  % if right heel strike event detected, ...
                            phase = 3;    % progress to double stance
                            datlog.stepdata.RHSdata(RstepCount-1,:) = [RstepCount-1,now,framenum.Value];
                            RHSTime(RstepCount) = now;
                            RHSTime2(RstepCount) = framenum.Value / rateFrame;
                            RHSPos(RstepCount) = posBodyY;
                            % compute most recent step R leg speed (mm/s)
                            speedRight = abs(RHSPos(RstepCount) - RHSPos(RstepCount-1)) / ...
                                (RHSTime2(RstepCount) - RHSTime2(RstepCount-1));
                            % RHS marks the end of single stance L
                            % update speed (convert to m/s) and step count
                            % GUI textboxes
                            set(ghandle.RBeltSpeed_textbox,'String',num2str(speedRight/1000));
                            set(ghandle.Right_step_textbox,'String',num2str(RstepCount-1));
                            % add step velocity to the GUI figure
                            addpoints(ppp4,RstepCount-1,speedRight/1000);
                            %                             plot(ghandle.profileaxes,RstepCount-1,velR(RstepCount)/1000,'o','MarkerFaceColor',[1 0.6 0.78],'MarkerEdgeColor','r');
                            % drawnow;
                            
                            % for H-reflex, stim is allowed after HS
                            %FIXME: If getting stimulated too much, turn this block off.
                            canStimR = true;
                            
                            if LTO	% in case DS is too short and a full cycle misses the phase switch
                                phase = 2;
                                LstepCount = LstepCount + 1;
                                LTOTime(LstepCount) = now;
                                LTOTime2(LstepCount) = framenum.Value / rateFrame;
                                LTOPos(LstepCount) = posBodyY;
                                % compute most recent step L speed (mm/s)
                                speedLeft = abs(LTOPos(LstepCount) - LTOPos(LstepCount-1)) / ...
                                    (LTOTime2(LstepCount) - LTOTime2(LstepCount-1));
                                % update speed and step count GUI textboxes
                                set(ghandle.LBeltSpeed_textbox,'String',num2str(speedLeft/1000));
                                set(ghandle.Left_step_textbox,'String',num2str(LstepCount-1));
                                datlog.stepdata.LTOdata(LstepCount-1,:) = [LstepCount-1,now,framenum.Value];
                            end
                        end
                    case 2      % single stance right leg
                        if LHS  % if left heel strike event detected, ...
                            phase=4;    % progress to double stance
                            datlog.stepdata.LHSdata(LstepCount-1,:) = [LstepCount-1,now,framenum.Value];
                            LHSTime(LstepCount) = now;
                            LHSTime2(LstepCount) = framenum.Value / rateFrame;
                            LHSPos(LstepCount) = posBodyY;
                            % compute most recent step left leg speed
                            speedLeft = abs(LHSPos(LstepCount) - LHSPos(LstepCount-1)) / ...
                                (LHSTime2(LstepCount) - LHSTime2(LstepCount-1));
                            % LHS marks the end of single stance R
                            % update speed and step count GUI textboxes
                            set(ghandle.LBeltSpeed_textbox,'String',num2str(speedLeft/1000));
                            set(ghandle.Left_step_textbox,'String',num2str(LstepCount-1));
                            % add step velocity to the GUI figure
                            addpoints(ppp3,LstepCount-1,speedLeft/1000);
                            %                             plot(ghandle.profileaxes,LstepCount-1,velL(LstepCount)/1000,'o','MarkerFaceColor',[0.68 .92 1],'MarkerEdgeColor','b');
                            % drawnow;
                            
                            %for H-reflex, stim is allowed after HS
                            %FIXME: If getting stimulated too much, turn this block off.
                            canStimL = true;
                            
                            if RTO  % in case DS is too short and a full cycle misses the phase switch
                                phase = 1;
                                RstepCount = RstepCount + 1;
                                RTOTime(RstepCount) = now;
                                RTOTime2(RstepCount) = framenum.Value / rateFrame;
                                RTOPos(RstepCount) = posBodyY;
                                % compute most recent step right leg speed
                                speedRight = abs(RTOPos(RstepCount) - RTOPos(RstepCount-1)) / ...
                                    (RTOTime2(RstepCount) - RTOTime2(RstepCount-1));
                                % update speed and step count GUI textboxes
                                set(ghandle.RBeltSpeed_textbox,'String',num2str(speedRight/1000));
                                set(ghandle.Right_step_textbox,'String',num2str(RstepCount-1));
                                datlog.stepdata.RTOdata(RstepCount-1,:) = [RstepCount-1,now,framenum.Value];
                            end
                        end
                    case 3      % double stance from SSL
                        if LTO  % if left toe off event detected, ...
                            phase = 2;  % progress to single stance right
                            LstepCount = LstepCount + 1;% increment counter
                            LTOTime(LstepCount) = now;
                            LTOTime2(LstepCount) = framenum.Value / rateFrame;
                            LTOPos(LstepCount) = posBodyY;
                            % compute most recent step left leg speed
                            speedLeft = abs(LTOPos(LstepCount) - LTOPos(LstepCount-1)) / ...
                                (LTOTime2(LstepCount) - LTOTime2(LstepCount-1));
                            % update speed and step count GUI textboxes
                            set(ghandle.LBeltSpeed_textbox,'String',num2str(speedLeft/1000));
                            set(ghandle.Left_step_textbox,'String',num2str(LstepCount-1));
                            datlog.stepdata.LTOdata(LstepCount-1,:) = [LstepCount-1,now,framenum.Value];
                        end
                    case 4      % double stance from SSR
                        if RTO  % if right toe off event detected, ...
                            phase = 1;   % progress to single stance left
                            RstepCount = RstepCount + 1;% increment counter
                            RTOTime(RstepCount) = now;
                            RTOTime2(RstepCount) = framenum.Value / rateFrame;
                            RTOPos(RstepCount) = posBodyY;
                            % compute most recent step right leg speed
                            speedRight = abs(RTOPos(RstepCount) - RTOPos(RstepCount-1)) / ...
                                (RTOTime2(RstepCount) - RTOTime2(RstepCount-1));
                            % update speed and step count GUI textboxes
                            set(ghandle.RBeltSpeed_textbox,'String',num2str(speedRight/1000));
                            set(ghandle.Right_step_textbox,'String',num2str(RstepCount-1));
                            datlog.stepdata.RTOdata(RstepCount-1,:) = [RstepCount-1,now,framenum.Value];
                        end
                end
                % if reached north end (i.e., computer side) of walkway, ...
            elseif posBodyY <= y_min
                phase = 0;  % reset the gait phase to initial phase
                if RstepCount ~= LstepCount % if different step counts, ...
                    if RstepCount > LstepCount  % if R greater than L, ...
                        LstepCount = RstepCount;% give 'em another R step
                    else                 % otherwise, L greater than R, ...
                        RstepCount = LstepCount;% give 'em another L step
                    end
                end
                tN = clock; % store time for audio feedback
                canGiveFdbkN = true; % feedback can be provided
                % if reached the south end (i.e., door side) or walkway, ...
            elseif posBodyY >= y_max
                phase = 0;  % reset the gait phase to initial phase
                if RstepCount ~= LstepCount % if different step counts, ...
                    if RstepCount > LstepCount  % if R greater than L, ...
                        LstepCount = RstepCount;% give 'em another R step
                    else                 % otherwise, L greater than R, ...
                        RstepCount = LstepCount;% give 'em another L step
                    end
                end
                tS = clock; % store time for audio feedback
                canGiveFdbkS = true; % feedback can be provided
            end
            
            if canGiveFdbkN && canGiveFdbkS % if feedback can be given, ...
                t2WalkPath = tN - tS;   % compute time difference
                % compute the time to walk the entire walkway for feedback
                durWalkPath = abs((t2WalkPath(4)*3600) + ...
                    (t2WalkPath(5)*60) + t2WalkPath(6));
                datlog.walkTime(end+1) = durWalkPath;   % store data log
                canGiveFdbkN = false;
                canGiveFdbkS = false;   % reset booleans to handle turns
                if giveFeedback     % if giving speed audio feedback, ...
                    if durWalkPath < fastest% if quicker than fastest, ...
                        play(instructions('fast')); % too fast
                        datlog.OGspeed.Performance(end+1,:) = [RstepCount-1, now, framenum.Value, 1];
                    elseif durWalkPath > slowest % if slower than slowest, ...
                        play(instructions('slow')); % too slow
                        datlog.OGspeed.Performance(end+1,:) = [RstepCount-1, now, framenum.Value, -1];
                    else            % otherwise, ...
                        play(instructions('good')); % good job
                        datlog.OGspeed.Performance(end+1,:) = [RstepCount-1, now, framenum.Value, 0];
                    end
                end
            end
            
            %% added by Yashar to count steps OG and for verbal feedback action
            
            %             % compute the average position along walkway (i.e., y-axis)
            %             % based on the Greater Trochanter markers
            %             body_y_pos(frameind.Value) = (LHIP_pos(2)+RHIP_pos(2))/2;
            %             % compute the translation along the walkway from the previous
            %             % to the current frame
            %             body_y_pos_diff(frameind.Value) = body_y_pos(frameind.Value) - body_y_pos(frameind.Value-1);
            %             % difference in left and right ankle position along the walkway
            %             Ank_diff(frameind.Value) = LANK_pos(2) - RANK_pos(2);
            %             % change in ankle difference between current and previous frame
            %             Ank_diffdiff(frameind.Value) = Ank_diff(frameind.Value)-Ank_diff(frameind.Value-1);
            %
            %             % if participant is between minimum and maximum y-axis value
            %             % (i.e., in the middle portion of the walkway) and at least pad
            %             % (i.e., 50) frames since most recent heel strike frame, ...
            %             if body_y_pos(frameind.Value) > y_min && ...
            %                     body_y_pos(frameind.Value) < y_max && ...
            %                     framenum.Value-HS_frame>pad
            %
            %                 % if walking in positive direction along the walkway and
            %                 % ...
            %                 if body_y_pos_diff(frameind.Value) >= 0 && ...
            %                         Ank_diffdiff(frameind.Value) >= 0 && ...
            %                         sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
            %
            %                     % store left heel strike event in array
            %                     Left_HS(frameind.Value) = 1;
            %                     sumiL = sum(Left_HS);   % total left heel strikes
            %                     HS_frame = framenum.Value;
            %                     % store left heel strike time for log
            %                     LHS_time = [LHS_time framenum.Value/rateFrame];
            %                     LHS_pos = [LHS_pos body_y_pos(frameind.Value)/1000];
            %                     % compute instaneous left leg speed as the difference
            %                     % in position divided by the difference in time
            %                     OG_speed_left = (LHS_pos(end)-LHS_pos(end-1))/(LHS_time(end)-LHS_time(end-1));
            %
            %                     % update speed and step count GUI textboxes
            %                     set(ghandle.LBeltSpeed_textbox,'String',num2str(OG_speed_left));
            %                     set(ghandle.Left_step_textbox,'String',num2str(sumiL));
            %                     LstepCount = LstepCount + 1;    % increment counter
            %                     canStim = true; % enable stimulation
            %
            %                     addpoints(ppp3,sumiL,OG_speed_left)
            %                     %addpoints(ppv1,sumiL,sumiL/1000)%paramCalibFunc(paramLHS)/1000)
            %
            %                 elseif body_y_pos_diff(frameind.Value) >= 0 && Ank_diffdiff(frameind.Value) < 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
            %                     % store right heel strike event in array
            %                     Right_HS(frameind.Value) = 1;
            %                     sumiR = sum(Right_HS);  % total right heel strikes
            %                     HS_frame = framenum.Value;
            %                     % store right heel strike time for log
            %                     RHS_time = [RHS_time framenum.Value/rateFrame];
            %                     RHS_pos = [RHS_pos body_y_pos(frameind.Value)/1000];
            %                     OG_speed_right = (RHS_pos(end)-RHS_pos(end-1))/(RHS_time(end)-RHS_time(end-1));
            %
            %                     set(ghandle.RBeltSpeed_textbox,'String',num2str(OG_speed_right));
            %                     set(ghandle.Right_step_textbox,'String',num2str(sumiR))
            %                     RstepCount = RstepCount + 1;    % increment counter
            %                     canStim = true; % enable stimulation
            %
            %                     addpoints(ppp4,sumiR,OG_speed_right);
            %                     %addpoints(ppv2,sumiR,sumiR/1000)%paramCalibFunc(paramRHS)/1000)
            %
            %                 elseif body_y_pos_diff(frameind.Value) < 0 && Ank_diffdiff(frameind.Value) >= 0 && sign(Ank_diffdiff(frameind.Value)) ~= sign(Ank_diffdiff(frameind.Value-1))
            %                     Right_HS(frameind.Value) = 1;
            %                     sumiR = sum(Right_HS);
            %                     HS_frame = framenum.Value;
            %                     RHS_time = [RHS_time framenum.Value/rateFrame];
            %                     RHS_pos = [RHS_pos body_y_pos(frameind.Value)/1000];
            %                     OG_speed_right = abs((RHS_pos(end)-RHS_pos(end-1))/(RHS_time(end)-RHS_time(end-1)));
            %
            %                     set(ghandle.RBeltSpeed_textbox,'String',num2str(OG_speed_right));
            %                     set(ghandle.Right_step_textbox,'String',num2str(sumiR))
            %                     RstepCount = RstepCount + 1;
            %                     canStim = true;
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
            %                     LstepCount = LstepCount + 1;
            %                     canStim = true;
            %
            %                     addpoints(ppp3,sumiL,OG_speed_left)
            %                 end
            %
            %                 % if reached north end (i.e., computer side) of walkway, ...
            %             elseif body_y_pos(frameind.Value) <= y_min
            %                 t1 = clock; % store the time for audio feedback of speed
            %                 inout1 = 1;
            %
            %                 % if reached the south end (i.e., door side) or walkway, ...
            %             elseif body_y_pos(frameind.Value) >= y_max
            %                 t2 = clock; % store the time for audio feedback of speed
            %                 inout2 = 1;
            %             end
            %
            %             if inout1 == 1 && inout2 == 1
            %                 t_diff = t1-t2; % compute the time difference
            %                 % compute the time to walk the entire walkway for feedback
            %                 walk_duration = abs((t_diff(4)*3600)+(t_diff(5)*60)+t_diff(6));
            %                 datlog.walkTime(end+1) = walk_duration; % store data log
            %                 inout1 = 0; % reset to handle the turns
            %                 inout2 = 0;
            %                 if (giveFeedback)   % if giving speed audio feedback, ...
            %                     if walk_duration < fastest
            %                         play(instructions('fast')); % too fast
            %                         datlog.OGspeed.Performance(end+1,1) = 1;
            %                     elseif walk_duration > slowest
            %                         play(instructions('slow')); % too slow
            %                         datlog.OGspeed.Performance(end+1,1) = -1;
            %                     else            % otherwise, ...
            %                         play(instructions('good')); % good job
            %                         datlog.OGspeed.Performance(end+1,1) = 0;
            %                     end
            %                 end
            %             end
            
            %% Implementation of H-Reflex Stimulation During OG Walking
            
            % TODO: there is an issue with the left leg being stimulated
            % during stance and then the right leg immediately being
            % stimulated mid-stance when the hip is right above the ankle.
            % One way to resolve this could be to ensure that the GT, KNEE,
            % and ANK are colinear. Enforcing the phase constraint was not
            % working since the hip was already forward of the ankle for
            % some participants during single stance.
            
            if hreflex_present  % if H-reflex stimulator is present, ...
                % timeSinceLastStim = toc;
                % if ten strides since last stimulation AND current phase
                % is single stance right leg AND stimulation is enabled AND
                % GT marker above ANK marker (mid-stance), ...
                if (mod(RstepCount,stimInterval) == 4 && ...
                        canStimR && phase == 2 && ... % tried: (timeSinceLastStim > 3) && ... % previously had: phase == 2 &&
                        (abs(RHIP_pos(2) - RANK_pos(2)) <= epsilon))
                    fprintf(arduinoPort,1); %1 is always stim right, hard-coded here and in Arduino. Don't change this.
                    canStimR = false; % don't stim again until LHS
                    % tic;                % reset the stim timer
                    datlog.stim.R(end+1,:) = [RstepCount, abs(RHIP_pos(2) - RANK_pos(2)),RHIP_pos(2),RANK_pos(2)];
                end
                
                % Changed to using ONLY RstepCount to force stimulation
                % order of left and right within one stride
                if (mod(RstepCount,stimInterval) == 4 && ...
                        canStimL && phase == 1 && ... % tried: (timeSinceLastStim > 3) && ... % previously had: phase == 1 &&
                        (abs(LHIP_pos(2) - LANK_pos(2)) <= epsilon))
                    fprintf(arduinoPort,2); %stim left
                    canStimL = false; %don't stim right away.
                    datlog.stim.L(end+1,:) = [RstepCount, abs(LHIP_pos(2) - LANK_pos(2)),LHIP_pos(2),LANK_pos(2)];
                end
                
                %%FIXME: If getting stimulated too much, turn this block on.
                %                 if (mod(RstepCount,stimInterval) == 7)
                %                     canStimR = true;
                %                     canStimL = true;
                %                 end
                
            end
            
            old_velL.Value = velL(LstepCount);
            old_velR.Value = velR(RstepCount);
            
        end
    end %While, when STOP button is pressed
    
    if STOP
        datlog.messages(end+1,:) = {'Stop button pressed at: [see next cell], stopping... ', now};
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
    disp(ME);
end
try
    save(savename,'datlog');
catch ME
    disp(ME);
end

if hreflex_present %if hreflex, close communication with arduino.
    datlog.messages(end+1,:) = {'Closing Arduino Port ', now};
    fprintf('Closing Arduino Port');
    fclose(arduinoPort);
    fprintf('Done Closing Arduino Port\n');
end

disp('closing comms');
try
    % keyboard
    disp('Closing Nexus Client')
    disp(clock);
    closeNexusIface(MyClient);
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
if temp >1 %SL added 04/10/2024, sometimes will have the first entry = 0, the following operation will remove all framenumber data, which will cause the code after to break when trying to compute etime from framenumebr 1
    %unclear why we want to delete framenumber = 0 or why we would find
    %that entry.
    datlog.framenumbers.data(temp:end,:) = [];
    for z = 1:temp-1
        datlog.framenumbers.data(z,3) = etime(datevec(datlog.framenumbers.data(z,2)),datevec(datlog.framenumbers.data(1,2)));
    end
end
%convert RHS times
temp = find(datlog.stepdata.RHSdata(:,1) == 0,1,'first');
if temp >1 %SL added 04/10/2024, sometimes will have the first entry = 0, the following operation will remove all framenumber data, which will cause the code after to break when trying to compute etime from framenumebr 1
    %unclear why we want to delete framenumber = 0 or why we would find
    %that entry.
    datlog.stepdata.RHSdata(temp:end,:) = [];
    datlog.stepdata.paramRHS(temp:end,:) = [];
    for z = 1:temp-1
        datlog.stepdata.RHSdata(z,4) = etime(datevec(datlog.stepdata.RHSdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
    end
end

%convert LHS times
temp = find(datlog.stepdata.LHSdata(:,1) == 0,1,'first');
if temp >1%SL added 04/10/2024, sometimes will have the first entry = 0, the following operation will remove all framenumber data, which will cause the code after to break when trying to compute etime from framenumebr 1
    %unclear why we want to delete framenumber = 0 or why we would find
    %that entry.
    datlog.stepdata.LHSdata(temp:end,:) = [];
    datlog.stepdata.paramLHS(temp:end,:) = [];
    for z = 1:temp-1
        datlog.stepdata.LHSdata(z,4) = etime(datevec(datlog.stepdata.LHSdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
    end
end

%convert RTO times
temp = find(datlog.stepdata.RTOdata(:,1) == 0,1,'first');
if temp >1 %SL added 04/10/2024, sometimes will have the first entry = 0, the following operation will remove all framenumber data, which will cause the code after to break when trying to compute etime from framenumebr 1
    %unclear why we want to delete framenumber = 0 or why we would find
    %that entry.
    datlog.stepdata.RTOdata(temp:end,:) = [];
    for z = 1:temp-1
        datlog.stepdata.RTOdata(z,4) = etime(datevec(datlog.stepdata.RTOdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
    end
end

%convert LTO times
temp = find(datlog.stepdata.LTOdata(:,1) == 0,1,'first');
if temp >1 %SL added 04/10/2024, sometimes will have the first entry = 0, the following operation will remove all framenumber data, which will cause the code after to break when trying to compute etime from framenumebr 1
    %unclear why we want to delete framenumber = 0 or why we would find
    %that entry.
    datlog.stepdata.LTOdata(temp:end,:) = [];
    for z = 1:temp-1
        datlog.stepdata.LTOdata(z,4) = etime(datevec(datlog.stepdata.LTOdata(z,2)),datevec(datlog.framenumbers.data(1,2)));
    end
end

datlog.walkTime = datlog.walkTime';
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
    disp(['R=' num2str(mean(datlog.stepdata.paramRHS(i1:end),'omitnan')) ', L=' num2str(mean(datlog.stepdata.paramLHS(i2:end),'omitnan'))])
end

disp('saving datlog...');
try
    save(savename,'datlog');
    [d,~,~]=fileparts(which(mfilename));
    save([d '\..\datlogs\lastDatlog.mat'],'datlog');
catch ME
    disp(ME);
end

