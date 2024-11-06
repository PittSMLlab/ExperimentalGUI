function [eventSteps, eventNames] = parseEventsFromSpeeds(velL, velR)
% Parase speeds and generate 2 arrays of the same size, 1st one is steps where an event
% occurs and should be logged, 2nd is a cell array with the corresponding
% evenet names (Rest, Split, PostTied, Mid, or AccRamp).
% both leg 0 = Rest
% leg speed different btw L and R, and btw previous step: ramp
% leg speed diff btw L and R but same as previous step: split
% leg speed same and !=0: mid or post depending on previous cnodition.
%
%Input:
%   velL: column double vector of the left belt speed
%   velR: column double vector of the right belt speed. 
%Output:
%   eventSteps: number array, steps where an event occurs and should be
%           logged.
%   eventName: cell array with the corresponding evenet names (Rest, Split, PostTied, Mid, or AccRamp).
%       both arrays have the same size.
    
    accramp = [0;diff(velR) > 0]; 
    moving = ~(velL == 0 | velR == 0);
    split = (velL - velR)~=0;
    splitramp = [0;diff(abs(velR - velL)) > 0];
    accramp = accramp & (~splitramp);
    speedState = moving + splitramp + split + accramp*0.5; %here 0 =rest, 1=tied, 1.5 = ramp to tied, 2=split, 3=ramp
    dcc = [0;diff(velR)<0 & diff(velL)< 0 & moving(2:end)];
    %if it's an abrupt protocol will treat the 1st split strides as ramp
    %and the next split stride as full split --> technically correct,
    %1stride ramp. Leave as is. Later has options to analyze start from
    %ramp or 1 stride later.
    %If a protocol starts walking right away with no rest, the first
    %walking start will not also be an event, that needs to be logged
    %manually (stride 1 is not a speed change, which makes sense)
    %steady state/regular walking start at step n bc n-1 and n+1 have the
    %same speed (i.e,. velL=velR = veln = vel_n-1=vel_n+1)
    speedChanges = diff(speedState);
    eventSteps = find(speedChanges)+1;
    %TODO: need to check compatability
    if speedState(1) == 0 && speedChanges(1) == 0 %start with at least 2 stride of rest
        %assume if first 2 strides are rest, it's a full on/long rest.
        eventSteps = [1;eventSteps]; %include 1st rest event. 
    end
    eventType = speedState(eventSteps);
    
    eventSteps = [eventSteps;find(dcc)];
    [eventSteps,sortIdx] = sort(eventSteps);
    eventType = [eventType;repmat(100,size(find(dcc)))];
    eventType = eventType(sortIdx);
    
    eventNames = cell(numel(eventSteps),1);
    for enIdx = 1:numel(eventType)
        en = eventType(enIdx);
        if en == 0
            eventNames{enIdx} = 'Rest';
        elseif en ==1 %this could be pre or post tied
            if enIdx >= 2 && strcmp(eventNames{enIdx-1},'Split') %previously split
                eventNames{enIdx} = 'PostTied';
            else
                eventNames{enIdx} = 'Mid';
            end
        elseif en == 3
            eventNames{enIdx} = 'DccRamp2Split';
        elseif en == 2
            eventNames{enIdx} = 'Split';
        elseif en == 1.5
            eventNames{enIdx} = 'AccRamp';
        elseif en == 100
            eventNames{enIdx} = 'ChangeSpeedToSlow';
        end
        %the event words are chosen such that the first letters are
        %different bc the letters will be used as event codes (1 digit) in
        %NIRS.
    end
end