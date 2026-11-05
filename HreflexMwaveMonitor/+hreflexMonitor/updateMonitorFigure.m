function updateMonitorFigure(handles, state, bounds, numRequired)
%UPDATEMONITORFIGURE Update the M-wave monitor's figure in place.
%
%   Shows the latest snippet, the amplitude trends, and whether the
% consecutive out-of-window rule has been met (COMPUTEMWAVEALERT). The
% figure background also turns pale red during an alert, so it can be seen
% without reading the title. Does not call DRAWNOW; the caller decides
% when to flush.
%
% Inputs:
%   handles     - struct from CREATEMONITORFIGURE
%   state       - running state from STEPHREFLEXMONITOR
%   bounds      - 1x2 [lowerBound upperBound], mV
%   numRequired - consecutive out-of-window stimuli that raise the alert
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None
%
% See also CREATEMONITORFIGURE, COMPUTEMWAVEALERT, STEPHREFLEXMONITOR.

arguments
    handles     (1,1) struct
    state       (1,1) struct
    bounds      (1,2) double
    numRequired (1,1) double
end

colorAlert = [1 0.85 0.85];   % pale red figure background
colorWarn  = [0.85 0.4 0];    % orange: out of window, rule not yet met
colorOk    = [0 0.5 0];       % green: inside the window

numStim = size(state.amps, 1);
if numStim == 0
    return;     % only invalid stimuli so far; nothing to plot
end

%% Latest Snippet
latestSnippet = state.snippets(end, :);
markerInds = state.mWaveInds(end, :);   % [indMin indMax]
set(handles.snippetLine, 'YData', latestSnippet);
set(handles.mWaveMarker, 'XData', handles.timesSnippetMs(markerInds), ...
    'YData', latestSnippet(markerInds));
set(handles.title, 'String', sprintf( ...
    'Stim #%d - M-wave: %.3f mV, H-wave: %.3f mV', ...
    numStim, state.amps(end, 1), state.amps(end, 2)));

%% Amplitude Trends
set(handles.trendLine, 'XData', 1:numStim, 'YData', state.amps(:, 1));
set(handles.hWaveLine, 'XData', 1:numStim, 'YData', state.amps(:, 2));

%% Consecutive Out-of-Window Rule
alert = hreflexMonitor.computeMwaveAlert(state.amps(:, 1), bounds, ...
    'numRequired', numRequired);
if alert.isAlert
    set(handles.indicator, 'String', sprintf( ...
        'ADJUST CURRENT: M-wave %s, %d in a row', alert.direction, ...
        alert.numConsecutive), 'Color', 'r');
    set(handles.fig, 'Color', colorAlert);
elseif alert.numConsecutive > 0
    set(handles.indicator, 'String', sprintf( ...
        'OUT OF WINDOW: M-wave %s, %d in a row', alert.direction, ...
        alert.numConsecutive), 'Color', colorWarn);
    set(handles.fig, 'Color', handles.colorDefault);
else
    set(handles.indicator, 'String', 'IN WINDOW', 'Color', colorOk);
    set(handles.fig, 'Color', handles.colorDefault);
end

end
