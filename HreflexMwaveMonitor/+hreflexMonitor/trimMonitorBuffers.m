function state = trimMonitorBuffers(state, options)
%TRIMMONITORBUFFERS Drop old raw samples from the running pipeline state.
%
%   STEPHREFLEXMONITOR and DETECTSTIMARTIFACTONLINE append to their raw
% sample buffers on every chunk, and appending copies the whole buffer.
% On a long live run that cost would grow until reads fell behind the
% stream, so the live loop calls this periodically. Accumulated snippets
% and amplitudes are kept; only raw samples no pending stimulus needs are
% dropped, and pending artifact indices are shifted to match.
%
% Inputs:
%   state - running state from STEPHREFLEXMONITOR, or []
%
% Optional Name-Value Inputs:
%   keepS - seconds of newest raw samples to keep (default: 2)
%
% Outputs:
%   state - updated state; unchanged if nothing can be dropped
%
% Toolbox Dependencies:
%   None
%
% See also STEPHREFLEXMONITOR, DETECTSTIMARTIFACTONLINE,
%   RUNHREFLEXMWAVEMONITORLIVE.

arguments
    state
    options.keepS (1,1) double {mustBePositive} = 2
end

guardOnsetS   = 0.15;    % s; kept before a pending onset, wider than the
                         % detector's default 100 ms search half-window
guardArtifactS = 0.01;   % s; kept before a pending artifact, wider than
                         % HREFLEX.EXTRACTSNIPPETS' 5 ms pre-artifact span

if isempty(state) || isempty(state.detect) || isnan(state.detect.period)
    return;
end
detect = state.detect;
period = detect.period;

%% Limit the Drop So Pending Stimuli Keep Their Samples
numDrop = numel(detect.times) - round(options.keepS / period);
if ~isempty(detect.pendingOnsetTimes)
    firstNeededTime = min(detect.pendingOnsetTimes) - guardOnsetS;
    numDrop = min(numDrop, sum(detect.times < firstNeededTime));
end
if ~isempty(state.pending)
    firstNeededInd = min(state.pending(:, 2)) ...
        - round(guardArtifactS / period);
    numDrop = min(numDrop, firstNeededInd - 1);
end
if numDrop <= 0
    return;
end

%% Drop the Samples and Shift the Pending Indices
detect.times(1:numDrop) = [];
detect.trig(1:numDrop)  = [];
detect.tap(1:numDrop)   = [];
state.detect = detect;
state.hBuf(1:numDrop) = [];
if ~isempty(state.pending)
    state.pending(:, 2) = state.pending(:, 2) - numDrop;
end

end
