function [eventSteps, eventNames] = parseEventsFromSpeeds(velL, velR)
%PARSEEVENTSFROMSPEEDS Parse speed vectors to identify trial phase boundaries.
%
%   Returns the stride indices where a phase transition occurs and a
%   label for each transition. Detects Rest, tied walking, acceleration
%   ramps, split-belt phases, post-split tied phases, and deceleration
%   events.
%
% Inputs:
%   velL - left-belt speed profile, Nx1 column vector (mm/s)
%   velR - right-belt speed profile, Nx1 column vector (mm/s)
%
% Outputs:
%   eventSteps - numeric column vector of stride indices where a phase
%                transition occurs
%   eventNames - cell array of strings (same length as eventSteps) with
%                one of: 'Rest', 'Mid', 'AccRamp', 'Split', 'PostTied',
%                'DccRamp2Split', 'ChangeSpeedToSlow'
%
% Toolbox Dependencies:
%   None
%
% See also NIRSAUTOMATICITYASSESSMENT, NIRSHREREFLEXOPENLOOPWITHAUDIO.

accramp = [0; diff(velR) > 0];
moving = ~(velL == 0 | velR == 0);
split = (velL - velR) ~= 0;
splitramp = [0; diff(abs(velR - velL)) > 0];
accramp = accramp & (~splitramp);
% here 0 = rest, 1 = tied, 1.5 = ramp to tied, 2 = split, 3 = ramp to split
speedState = moving + splitramp + split + accramp * 0.5;
dcc = [0; diff(velR) < 0 & diff(velL) < 0 & moving(2:end)];
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
eventSteps = find(speedChanges) + 1;
%TODO: need to check compatability
if speedState(1) == 0 && speedChanges(1) == 0 %start with at least 2 stride of rest
    %assume if first 2 strides are rest, it's a full on/long rest.
    eventSteps = [1; eventSteps]; %include 1st rest event.
end
eventType = speedState(eventSteps);

eventSteps = [eventSteps; find(dcc)];
[eventSteps, sortIdx] = sort(eventSteps);
eventType = [eventType; repmat(100, size(find(dcc)))];
eventType = eventType(sortIdx);

eventNames = cell(numel(eventSteps), 1);
for ii = 1:numel(eventType)
    en = eventType(ii);
    if en == 0
        eventNames{ii} = 'Rest';
    elseif en == 1 %this could be pre or post tied
        if ii >= 2 && strcmp(eventNames{ii - 1}, 'Split') %previously split
            eventNames{ii} = 'PostTied';
        else
            eventNames{ii} = 'Mid';
        end
    elseif en == 3
        eventNames{ii} = 'DccRamp2Split';
    elseif en == 2
        eventNames{ii} = 'Split';
    elseif en == 1.5
        eventNames{ii} = 'AccRamp';
    elseif en == 100
        eventNames{ii} = 'ChangeSpeedToSlow';
    end
    %the event words are chosen such that the first letters are
    %different bc the letters will be used as event codes (1 digit) in
    %NIRS.
end

end
