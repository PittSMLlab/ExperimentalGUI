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

    moving = ~(velL == 0 | velR == 0);
    split = (velL - velR)~=0;
    ramp = [0;diff(abs(velR - velL)) > 0];
    speedState = moving + ramp + split; %here 0 =rest, 1=tied, 2=split, 3=ramp
    %if it's an abrupt protocol will treat the 1st split strides as ramp
    %and the next split stride as full split --> technically correct,
    %1stride ramp. Leave as is. Later has options to analyze start from
    %ramp or 1 stride later.
    speedChanges = diff(speedState);
    eventSteps = find(speedChanges)+1;
    if speedState(1) == 0 && speedChanges(1) == 0 %start with at least 2 stride of rest
        %assume if first 2 strides are rest, it's a full on/long rest.
        eventSteps = [1;eventSteps]; %include 1st rest event. 
    end
    eventType = speedState(eventSteps);
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
            eventNames{enIdx} = 'AccRamp';
        elseif en == 2
            eventNames{enIdx} = 'Split';
        end
    end
end