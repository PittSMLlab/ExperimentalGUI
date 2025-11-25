% -------------------------------------------------------------------------
% This script connects to an Arduino (or other serial device) to read
% left and right force-plate Z-axis values, logs them into a CSV file,
% displays a real-time plot of the last 2 seconds of data with dynamic
% y-axis scaling, and saves the final plot window.
% -------------------------------------------------------------------------
%% USER PARAMETERS
% Adjust these values before running
namePort    = "COM4";           % "COM4" Windows, "/dev/ttyACM0" Linux/Mac
baudRate    = 115200;           % must match Arduino's Serial.begin()
durationLog = 30;               % total logging time in seconds
dt = datetime('now');
dt.Format = 'yyyyMMddHHmmss';
dateString = string(dt);
outputFile  = "force_data_" + dateString + ".csv"; % path to CSV output file
durationPlot  = 2;              % seconds of data to display real-time plot

%% INITIALIZE SERIAL CONNECTION
% create serialport object (R2019b and newer)
try
    s = serialport(namePort,baudRate);
catch ME
    error("Failed to open serial port %s at %d baud.\n%s", ...
        namePort,baudRate,ME.message);
end
% assume Arduino sends newline-terminated data
configureTerminator(s,"LF");
flush(s);                       % flush buffer before starting logging

%% OPEN CSV FILE
fid = fopen(outputFile,'w');    % open output CSV file
if fid == -1
    clear s;
    error("Could not open output file: %s",outputFile);
end
% write header line
fprintf(fid,'Timestamp,LeftFz,RightFz\n');    % CSV header

%% SET UP REAL-TIME PLOT
hFig = figure('Name','Force Plate Z-Axis','NumberTitle','off');
hAx = axes(hFig);
hold(hAx,'on');
hLeft  = plot(hAx,nan,nan,'b-','DisplayName','Left Fz');
hRight = plot(hAx,nan,nan,'r-','DisplayName','Right Fz');
legend(hAx,'show');
xlabel(hAx,'Time (s)');
ylabel(hAx,'Force Z (bits)');
grid(hAx,'on');

%% START DATA ACQUISITION AND PLOTTING
fprintf('Logging force data and updating plot for %.1f seconds...\n', ...
    durationLog);
tStart = tic;
% data buffers
timeBuf  = [];
leftBuf  = [];
rightBuf = [];
leftStepBuf = [];
rightStepBuf = [];
phaseBuf = [];

while toc(tStart) < durationLog
    % read a line from serial device
    rawLine = readline(s);
    nums = sscanf(rawLine,'%lu,%d,%d,%d,%d,%d');
    if numel(nums) == 6
        tNow = toc(tStart);
        % append to buffers
        timeBuf(end+1)  = nums(1);  %#ok<SAGROW>
        leftBuf(end+1)  = nums(2);  %#ok<SAGROW>
        rightBuf(end+1) = nums(3);  %#ok<SAGROW>
        leftStepBuf(end+1) = nums(4);%#ok<SAGROW>
        rightStepBuf(end+1) = nums(5);%#ok<SAGROW>
        phaseBuf(end+1) = nums(6);  %#ok<SAGROW>
        % trim buffers to durationPlot
        idx   = timeBuf >= tNow - durationPlot;
        tPlot = timeBuf(idx);
        lPlot = leftBuf(idx);
        rPlot = rightBuf(idx);
        % update plot data
        set(hLeft,'XData',tPlot,'YData',lPlot);
        set(hRight,'XData',tPlot,'YData',rPlot);
        % dynamic y-axis limits
        allY = [lPlot rPlot];
        yMin = min(allY);
        yMax = max(allY);
        yRange = yMax - yMin;
        if yRange == 0
            margin = 1;
        else
            margin = 0.1 * yRange;
        end
        ylim(hAx,[yMin - margin yMax + margin]);
        xlim(hAx,[max(0,tNow-durationPlot) tNow]);
        drawnow limitrate;
        fprintf(fid,'%lu,%d,%d,%d,%d,%d\n',nums(1),nums(2),nums(3),nums(4),nums(5),nums(6)); % write to CSV
    else
        % optionally, display or log malformed lines
        fprintf('Warning: could not parse data: "%s"\n',rawLine);
    end
end

%% SAVE FINAL PLOT
folder = fileparts(outputFile);
plotFile = fullfile(folder,'force_plot_last2s.png');
try
    saveas(hFig,plotFile);
    fprintf('Final plot saved to %s\n',plotFile);
catch
    warning('Could not save plot to %s',plotFile);
end

%% CLEAN UP
fclose(fid);
clear s;
fprintf('Logging complete. CSV saved to %s\n',outputFile);

