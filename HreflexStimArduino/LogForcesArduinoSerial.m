% -------------------------------------------------------------------------
% This script connects to an Arduino (or other serial device) to read
% left and right force-plate Z-axis values, logs them into a CSV file,
% displays a real-time plot of the last 2 seconds of data with dynamic
% y-axis scaling, and saves the final plot window.
% -------------------------------------------------------------------------
%% USER PARAMETERS
% Adjust these values before running.
portName    = "COM3";           % "COM3" Windows, "/dev/ttyACM0" Linux/Mac
baudRate    = 9600;             % must match Arduino's Serial.begin()
durationSec = 60;               % total logging time in seconds
outputFile  = "force_data.csv"; % path to CSV output file
plotWindow  = 2;                % seconds of data to display real-time plot

%% INITIALIZE SERIAL CONNECTION
% Create serialport object (R2019b and newer)
try
    s = serialport(portName, baudRate);
catch ME
    error("Failed to open serial port %s at %d baud.\n%s", ...
        portName, baudRate, ME.message);
end
% assume Arduino sends newline-terminated data
configureTerminator(s, "LF");
flush(s);

%% OPEN CSV FILE
fid = fopen(outputFile, 'w');
if fid == -1
    clear s;
    error("Could not open output file: %s", outputFile);
end
% write header line
timestampFormat = 'yyyy-MM-dd HH:mm:ss.SSS';
fprintf(fid, 'Timestamp,LeftZ,RightZ\n');   % CSV header

%% SET UP REAL-TIME PLOT
hFig = figure('Name','Force Plate Z-Axis','NumberTitle','off');
hAx = axes(hFig);
hold(hAx,'on');
hLeft  = plot(hAx, nan, nan, 'b-', 'DisplayName','Left Z');
hRight = plot(hAx, nan, nan, 'r-', 'DisplayName','Right Z');
legend(hAx,'show');
xlabel(hAx,'Time (s)');
ylabel(hAx,'Force Z');
grid(hAx,'on');

%% START DATA ACQUISITION AND PLOTTING
fprintf('Logging force data and updating plot for %.1f seconds...\n', ...
    durationSec);
tStart = tic;
% data buffers
timeBuf  = [];
leftBuf  = [];
rightBuf = [];

while toc(tStart) < durationSec
    % read a line from serial device
    rawLine = readline(s);
    % expecting format: "%f,%f" (e.g. "12.34,56.78")
    nums = sscanf(rawLine, '%f,%f');
    if numel(nums) == 2
        tNow = toc(tStart);
        % append to buffers
        timeBuf(end+1)  = tNow;     %#ok<SAGROW>
        leftBuf(end+1)  = nums(1);  %#ok<SAGROW>
        rightBuf(end+1) = nums(2);  %#ok<SAGROW>
        % trim buffers to plotWindow
        idx   = timeBuf >= tNow - plotWindow;
        tPlot = timeBuf(idx);
        lPlot = leftBuf(idx);
        rPlot = rightBuf(idx);
        % update plot data
        set(hLeft,  'XData', tPlot, 'YData', lPlot);
        set(hRight, 'XData', tPlot, 'YData', rPlot);
        % dynamic y-axis limits
        allY = [lPlot, rPlot];
        yMin = min(allY);
        yMax = max(allY);
        yRange = yMax - yMin;
        if yRange == 0
            margin = 1;
        else
            margin = 0.1 * yRange;
        end
        ylim(hAx, [yMin - margin, yMax + margin]);
        xlim(hAx, [max(0, tNow-plotWindow), tNow]);
        drawnow limitrate;
        % write to CSV with timestamp
        ts = datestr(datetime('now'), timestampFormat);
        fprintf(fid, '%s,%.3f,%.3f\n', ts, nums(1), nums(2));
    else
        % optionally, display or log malformed lines
        fprintf('Warning: could not parse data: "%s"\n', rawLine);
    end
end

%% SAVE FINAL PLOT
[folder, ~, ~] = fileparts(outputFile);
plotFile = fullfile(folder, 'force_plot_last2s.png');
try
    saveas(hFig, plotFile);
    fprintf('Final plot saved to %s\n', plotFile);
catch
    warning('Could not save plot to %s', plotFile);
end

%% CLEAN UP
fclose(fid);
clear s;
fprintf('Logging complete. CSV saved to %s\n', outputFile);
