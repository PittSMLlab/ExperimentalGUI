function handles = createMonitorFigure(leg, muscle, baselineMwaveMv, bounds)
%CREATEMONITORFIGURE Create the M-wave monitor's persistent figure.
%
%   Plotted objects are created once here and updated in place by
% UPDATEMONITORFIGURE, never replotted, to keep per-update work bounded.
%
%   +-10% BOUNDS ARE NOT DRAWN ON THE SNIPPET AXES: M-wave amplitude is a
% peak-to-peak difference (mV), not a raw EMG voltage (V) sample, so a
% horizontal line at "baseline +- 10%" would not correspond to anything
% on that trace. The bounds live on the trend axes, whose y-axis IS
% amplitude.
%
% Inputs:
%   leg             - char; 'R' or 'L'
%   muscle          - char; H-reflex muscle label
%   baselineMwaveMv - scalar; baseline M-wave amplitude (mV)
%   bounds          - 1x2 [lowerBound upperBound], mV
%
% Outputs:
%   handles - struct of graphics handles for UPDATEMONITORFIGURE
%
% Toolbox Dependencies:
%   None
%
% See also UPDATEMONITORFIGURE, RUNHREFLEXMWAVEMONITOR,
%   RUNHREFLEXMWAVEMONITORLIVE.

arguments
    leg             (1,1) char
    muscle          (1,:) char
    baselineMwaveMv (1,1) double
    bounds          (1,2) double
end

numSnippetSamps = 121;   % -5:0.5:55 ms @ 2 kHz; HREFLEX.EXTRACTSNIPPETS

fig = figure('Name', sprintf('H-Reflex M-Wave Monitor (%s, %s)', ...
    leg, muscle), 'NumberTitle', 'off');

axSnippet = subplot(2, 1, 1, 'Parent', fig);
hold(axSnippet, 'on');
timesSnippetMs = 1000 * (-0.005:0.0005:0.055);
hSnippetLine = plot(axSnippet, timesSnippetMs, nan(1, numSnippetSamps), ...
    'Color', [0 0.45 0.74]);
hMwaveMarker = plot(axSnippet, nan(1, 2), nan(1, 2), 'ro-', ...
    'LineWidth', 1.5, 'MarkerFaceColor', 'r');
xlabel(axSnippet, 'Time Relative to Stim Artifact (ms)');
ylabel(axSnippet, 'EMG (V)');
titleHandle = title(axSnippet, 'Waiting for first stimulus...');
grid(axSnippet, 'on');

axTrend = subplot(2, 1, 2, 'Parent', fig);
hold(axTrend, 'on');
hTrendLine = plot(axTrend, nan, nan, 'o-', 'Color', [0 0.45 0.74], ...
    'MarkerFaceColor', [0 0.45 0.74]);
hHwaveLine = plot(axTrend, nan, nan, 's-', 'Color', [0.85 0.55 0.1], ...
    'MarkerFaceColor', [0.85 0.55 0.1]);
yline(axTrend, bounds(1), 'r--', 'LineWidth', 1);
yline(axTrend, bounds(2), 'r--', 'LineWidth', 1);
yline(axTrend, baselineMwaveMv, 'k:', 'LineWidth', 1);
legend(axTrend, [hTrendLine hHwaveLine], {'M-wave', 'H-wave'}, ...
    'Location', 'northeast');
xlabel(axTrend, 'Stimulus #');
ylabel(axTrend, 'Amplitude (mV)');
indicatorHandle = title(axTrend, '', 'FontWeight', 'bold');
statusHandle = text(axTrend, 0.02, 0.92, '', 'Units', 'normalized');
grid(axTrend, 'on');

handles = struct('fig', fig, 'colorDefault', get(fig, 'Color'), ...
    'timesSnippetMs', timesSnippetMs, 'snippetLine', hSnippetLine, ...
    'mWaveMarker', hMwaveMarker, 'title', titleHandle, ...
    'trendLine', hTrendLine, 'hWaveLine', hHwaveLine, ...
    'indicator', indicatorHandle, 'status', statusHandle);

end
