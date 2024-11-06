function [trialData]=datlogSummarizeTemp(datlog)
goodOnly=0;
%% Parse datlog to get HS, profiles, sent speeds
vRsent=datlog.TreadmillCommands.sent(:,1);
vLsent=datlog.TreadmillCommands.sent(:,2);
vSentT=datlog.TreadmillCommands.sent(:,4);
vRread=datlog.TreadmillCommands.read(:,1);
vLread=datlog.TreadmillCommands.read(:,2);
vReadT=datlog.TreadmillCommands.read(:,4);

vRload=datlog.speedprofile.velR;
vLload=datlog.speedprofile.velL;

RTO=datlog.stepdata.RTOdata;
LTO=datlog.stepdata.LTOdata;
RHS=datlog.stepdata.RHSdata;
LHS=datlog.stepdata.LHSdata;

pDuration=8;

try
    audiostart=datlog.audioCues.start;
    audiostop=datlog.audioCues.stop;
catch
    audiostart=[];
    audiostop=[];
end

if length(RHS)>length(LHS) %This means we started counting events at an RTO, and therefore RTOs mark new strides for the GUI and datlog
%     pTO=RTO; %Primary event
%     sTO=LTO; %Secondary event  
    pHS=RHS; %Primary event
    sHS=LHS; %Secondary event
    
else %LTOs mark new strides
%     pTO=LTO;
%     sTO=RTO;
    pHS=LHS; %Primary event
    sHS=RHS;
end

vR=interp1(vReadT,vRread,pHS(:,4),'nearest');
vL=interp1(vReadT,vLread,pHS(:,4),'nearest');
vR=interp1(vSentT,vRsent,pHS(:,4),'previous'); %Last sent speed BEFORE the event
vL=interp1(vSentT,vLsent,pHS(:,4),'previous'); %Last sent speed BEFORE the event
vD=vR-vL;


% Index were the audio cue should have started

% vDtemp = vD;
% vDtemp(vDtemp~=0) = 1;
% 
% ind = strfind(vDtemp',[0 1]);

% Not sure if this is the best way to do it
inds = [];

for i = 1:length(audiostart)
    
%     [minValue,closestIndex] = min(abs(pTO(:,4)-audiostart(i)));  
    [minValue,closestIndex] = min(abs(pHS(:,4)-audiostart(i)));   
    inds = [inds; closestIndex];
    
    
    %Voy a mirar el pert sie en ese indice y en el que le sigue, el que le
    %sigue tiene que estar en allowed y ser menor que ese, y el del indice
    %tiene que estar en los allowed  
    
end 

% trialStrides=isnan(vRload);
% inds=find(trialStrides(2:end) & ~trialStrides(1:end-1)); %Last automated stride control: start of trial!


Lpress=strcmp(datlog.addLog.keypress(:,1),'leftarrow') | strcmp(datlog.addLog.keypress(:,1),'numpad4') | strcmp(datlog.addLog.keypress(:,1),'pageup');
LpressT=(cell2mat(datlog.addLog.keypress(Lpress,2))); %New ver

Rpress=strcmp(datlog.addLog.keypress(:,1),'rightarrow') | strcmp(datlog.addLog.keypress(:,1),'numpad6') | strcmp(datlog.addLog.keypress(:,1),'pagedown');
RpressT=(cell2mat(datlog.addLog.keypress(Rpress,2))) ;

%% Find reaction times & accuracy of first keypress
[allPressT,sortIdxs]=sort([LpressT; RpressT]);
pressedKeys=[-1*ones(size(LpressT)); ones(size(RpressT))]; %R=1, L=-1
pressedKeys=pressedKeys(sortIdxs);
%isItRpress=pressedKeys==1;

%Define some variables for each trial:
reactionTime=nan(size(inds,1),1);
reactionStride=nan(size(inds,1),1);

pertSize=vD(inds(:,1),1);
 

%%

% changeSize=vD(inds(:,1))-vD(inds(:,1)-3);
pertSign=sign(pertSize);
reactionSign=nan(size(inds,1),1); %Positive if vR>vL
accurateReaction=nan(size(inds,1),1);
%goodTrial=zeros(size(inds));
pressTrial=nan(size(allPressT,1),1);
startCue=pHS(inds(:,1),4);
%endCue=pTO(inds(:,2),4);



for i=1:size(inds,1)
    
    if isempty(find(allPressT > startCue(i)-1,1,'first'))
        break
    end
    
        aux(i,1)=find(allPressT > startCue(i)-1,1,'first'); %Pablo previously had a minus 1 for the start cue
        
        aux2(i,1)=find(pHS(:,4) > allPressT(aux(i,1)),1,'first');

        if ~isempty(aux) && (aux2(i,1)-inds(i,1))<=pDuration
            reactionTime(i)=allPressT(aux(i,1))-startCue(i);
            reactionStride(i)=aux2(i)-inds(i);
            reactionSign(i) = pressedKeys(aux(i)); %R=1, L=-1
            if (pertSign(i) == -1*reactionSign(i)) % Positive pertSign means vR>vL %|| pertSign(i)==0 %Correct choice!
                accurateReaction(i)=true;
            else
                accurateReaction(i)=false;
            end
            
        end
         %aux=find((allPressT > startCue(i)) & (allPressT < endCue(i)+1)); %To address the possible differences between the endCue and the keyPress which will act sometimes as endCue, I add one second to this conditions
         pressTrial(aux)=i; 
        
%           if i == 47 %For a pilot block which had one less probe because
%           something weird happened with Nexus
%              i
%              break
%          end       


end

startStride = inds; %Inds are the stride number for the start cue

%% Filter trials & presses to consider:
if goodOnly==0
    mask=ones(size(inds(:,1))); %-> Override: Every trial is 'good'!
elseif goodOnly==-1
    mask=1-accurateReaction;
elseif goodOnly==1
    mask=accurateReaction;
end

    %Mask everything in trials:
    inds=inds(mask==1,:); %Keep only 'good' trials
    reactionTime=reactionTime(mask==1);
    reactionStride=reactionStride(mask==1);
    pertSize=vD(inds(:,1),1);
    pertSign=pertSign(mask==1);
    reactionSign=reactionSign(mask==1); %Positive if vR>vL
    accurateReaction=accurateReaction(mask==1);
    startCue=startCue(mask==1);
    %endCue=endCue(mask==1);
    
    %Fake trial number for presses outside a valid trial & expand goodTrial vector:
    pressTrial(isnan(pressTrial))=length(mask)+1; 
    mask(end+1)=0;
    
    %Filter presses to only those that happend during goodTrials
    LpressT=allPressT(pressedKeys==-1 & mask(pressTrial));
    RpressT=allPressT(pressedKeys==1 & mask(pressTrial));
    

%% Returns a matrix with the following columns:
%trial #, date+time, startTime, endTime, pertSize, reactionTime, reactionStride, initialResponse, 

startTime=audiostart;
endTime=nan(length(startTime),1); %Added for the times the controller stops and I have to stop the trial before if get to the end tone or a response
endTime(1:length(audiostop),1)=audiostop;
date=datenum(datlog.buildtime);

initialResponse=reactionSign;
date=date*ones(size(startTime));
trialData=table(date,startTime,endTime,startStride,pertSize,reactionTime,reactionStride,initialResponse);

end

