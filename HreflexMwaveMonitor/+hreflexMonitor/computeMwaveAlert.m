function alert = computeMwaveAlert(mWaveMv, bounds, options)
%COMPUTEMWAVEALERT Check for consecutive out-of-window M-wave stimuli.
%
%   Applies the current-adjustment rule: alert when the most recent
% stimuli are all outside the M-wave tolerance window, three in a row by
% default. Invalid stimuli never reach this function, so they neither add
% to nor reset the count.
%
% Inputs:
%   mWaveMv - numStim x 1 M-wave amplitudes (mV), oldest first
%   bounds  - 1x2 [lowerBound upperBound], mV (COMPUTEMWAVETOLERANCE)
%
% Optional Name-Value Inputs:
%   numRequired - consecutive out-of-window stimuli that raise the alert
%                 (default: 3)
%
% Outputs:
%   alert - struct with fields:
%             numConsecutive - out-of-window stimuli at the end of mWaveMv
%             isAlert        - true if numConsecutive >= numRequired
%             direction      - 'HIGH' or 'LOW' if every stimulus in the
%                              run is on that side, 'MIXED' if not, ''
%                              when the latest stimulus is in the window
%
% Toolbox Dependencies:
%   None
%
% See also COMPUTEMWAVETOLERANCE, UPDATEMONITORFIGURE.

arguments
    mWaveMv (:,1) double
    bounds  (1,2) double
    options.numRequired (1,1) double ...
        {mustBePositive, mustBeInteger} = 3
end

isOut = mWaveMv < bounds(1) | mWaveMv > bounds(2);
indLastIn = find(~isOut, 1, 'last');
if isempty(indLastIn)
    indLastIn = 0;
end
outRun = mWaveMv(indLastIn + 1:end);

alert.numConsecutive = numel(outRun);
alert.isAlert = alert.numConsecutive >= options.numRequired;
if isempty(outRun)
    alert.direction = '';
elseif all(outRun > bounds(2))
    alert.direction = 'HIGH';
elseif all(outRun < bounds(1))
    alert.direction = 'LOW';
else
    alert.direction = 'MIXED';
end

end
