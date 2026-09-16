% -------------------------------------------------------------------------
% This script connects to an Arduino running
% triggerStimWithGaitStateMachine_SpeedIndependent.ino to read left and
% right force-plate Z-axis values, logs them into a subject-tagged CSV
% file, displays a real-time plot of the last 2 seconds of data with
% dynamic y-axis scaling and threshFzUp/threshFzDown reference lines,
% and prints a signal-quality summary (baseline noise vs. threshFzUp) on
% completion.
%
% Bench-check prerequisite: the firmware's logForceData() call is
% commented out in production (line 297 of the .ino, inside
% updateGaitEventStateMachine()) so it never runs during a real trial.
% Before running this script, uncomment that ONE line -- not the
% differently named, argument-less logForceCSV() stub near the top of
% loop() (line 170), which does not exist as a function and will not
% compile -- then re-flash the sketch. Re-comment the line and re-flash
% the production build again before any participant session: left
% streaming on, logForceData() sends a CSV record every intervalLog
% (5 ms) from inside the stim control loop, and Serial.print blocks
% once the 64-byte UART TX buffer fills, which can stall loop() and
% triggerStimulation() -- the same failure class documented in
% HreflexStimArduino/README.md's H-reflex timing history. Run with the
% DS8R disconnected or at zero output current.
% -------------------------------------------------------------------------
%% USER PARAMETERS
% Adjust these values before running
namePort     = "COM4"; % "COM4" Windows, "/dev/ttyACM0" Linux/Mac
baudRate     = 115200; % must match Arduino's Serial.begin()
durationLog  = 30;     % total logging time in seconds
durationPlot = 2;      % seconds of data to display real-time plot

%% PROTOCOL & SIGNAL CONSTANTS
% Serial command bytes. Frozen by the H-reflex timing contract (see
% HreflexStimArduino/README.md) and sent as 'uint8' only -- a wider
% precision pads a trailing zero byte that the firmware reads as a
% spurious extra command one loop pass later (root cause of the
% 2026-08-05 pilot's missed/wrong-stride stims; see that README).
cmdArduinoStart = 0; % start (and reset) the gait-event state machine;
                      % logForceData() only executes while this is set
cmdArduinoStop  = 3; % stop the gait-event state machine
% Force thresholds (bits). Must match threshFzUp/threshFzDown in
% triggerStimWithGaitStateMachine_SpeedIndependent.ino: drawn as plot
% reference lines and used to define the baseline noise window below.
threshFzUp   = 30;
threshFzDown = 2;
% Timing constants
settleDelaySec = 2; % s; time for the Uno's DTR-triggered reset to
                     % finish before writing or flushing the port
timeoutSerial  = 2; % s; readline timeout. Short enough to fail fast if
                     % no data ever arrives (see the no-data check
                     % below); long enough to tolerate normal jitter
                     % between the ~5 ms records logForceData() sends
msPerSec = 1000; % unit conversion: ms -> s
numSDMargin = 3; % bits; conservative multiplier for the noise-margin
                  % summary printed at teardown
intervalMalformedWarn = 100; % lines; rate-limit the malformed-line
                              % warning so a baud mismatch does not
                              % flood the console

%% SUBJECT ID PROMPT
% Determines the output file basenames. Bench runs commonly use an
% experimenter's initials rather than a real subject ID, so a mismatch
% against the study ID formats below is a warning, not a rejection.
subjectIdPrompt = inputdlg( ...
    'Enter Subject ID (or initials for a bench check):', ...
    'LogForcesArduinoSerial',[1 50]);
if isempty(subjectIdPrompt) % Cancel pressed
    disp('Subject ID prompt cancelled. Exiting.');
    return;
end
subjectIdRaw = strtrim(subjectIdPrompt{1});
if isempty(subjectIdRaw)
    error('Subject ID cannot be empty.');
end
subjectID = regexprep(subjectIdRaw,'[^A-Za-z0-9_-]','_'); % filename-safe
studyIdPattern = '^(SABH\d{2}|SAS\d{2}V\d{2})$'; % SpinalAdapt formats
if isempty(regexpi(subjectID,studyIdPattern,'once'))
    warning(['Subject ID "%s" does not match a recognized study ID ' ...
        'format (SABH##, SAS##V##). Proceeding anyway -- expected ' ...
        'for a bench check using initials.'],subjectID);
end

%% OUTPUT PATHS
scriptFolder = fileparts(mfilename('fullpath'));
outputFolder = fullfile(scriptFolder,'forceChecks');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
dt = datetime('now');
dt.Format = 'yyyyMMddHHmmss';
dateString = string(dt);
outputFile = fullfile(outputFolder, ...
    "forces_" + subjectID + "_" + dateString + ".csv");
plotFile = fullfile(outputFolder, ...
    "forces_" + subjectID + "_" + dateString + ".png");

%% INITIALIZE SERIAL CONNECTION
% create serialport object (R2019b and newer)
try
    portArduino = serialport(namePort,baudRate,'Timeout',timeoutSerial);
catch ME
    error("Failed to open serial port %s at %d baud.\n%s", ...
        namePort,baudRate,ME.message);
end
configureTerminator(portArduino,"LF");
pause(settleDelaySec); % let the Uno finish its DTR-triggered reset
flush(portArduino);    % flush any boot-time garbage before starting

%% SET UP REAL-TIME PLOT
hFig = figure('Name','Force Plate Z-Axis','NumberTitle','off');
hAx = axes(hFig);
hold(hAx,'on');
hLeft  = plot(hAx,nan,nan,'b-','DisplayName','Left Fz');
hRight = plot(hAx,nan,nan,'r-','DisplayName','Right Fz');
yline(hAx,threshFzUp,'k--','threshFzUp');
yline(hAx,threshFzDown,'k:','threshFzDown');
legend(hAx,[hLeft hRight],{'Left Fz','Right Fz'},'Location','best');
xlabel(hAx,'Time (s)');
ylabel(hAx,'Force Z (bits)');
grid(hAx,'on');

%% ACQUIRE, LOG, AND PLOT
fid = -1;
try
    fid = fopen(outputFile,'w');
    if fid == -1
        error("Could not open output file: %s",outputFile);
    end

    write(portArduino,cmdArduinoStart,'uint8'); % start gait-event SM;
                                                 % logForceData() only
                                                 % runs while this is on

    fprintf(['Logging force data and updating plot for %.1f ' ...
        'seconds...\n'],durationLog);
    tStart = tic;

    % data buffers (timeBuf keeps the raw Arduino millis() for the CSV;
    % tBuf holds seconds elapsed since the first sample for plotting)
    timeBuf  = [];
    tBuf     = [];
    leftBuf  = [];
    rightBuf = [];

    recordTypeLocked = ''; % set once the first valid line establishes
                            % the CSV column format ('force3'/'force6')
    timeFirstMs   = [];
    numMalformed  = 0;

    while toc(tStart) < durationLog
        rawLine = readline(portArduino);

        % readline does not throw on timeout -- it warns and returns an
        % empty/missing string -- so a genuine "no data" condition must
        % be checked explicitly rather than relying on try/catch
        if ismissing(rawLine) || rawLine == ""
            error(['No data received from the Arduino within %g s. ' ...
                'Is logForceData(...) uncommented at line 297 of ' ...
                'triggerStimWithGaitStateMachine_SpeedIndependent.ino,' ...
                ' and has the sketch been re-flashed? (Do not confuse' ...
                ' it with the misnamed, argument-less logForceCSV()' ...
                ' stub at line 170 -- that function does not exist.)'], ...
                timeoutSerial);
        end

        [recordType,nums] = parseForceLine(rawLine);

        switch recordType
        case 'echo'
            continue; % this script never gates a stim; defensive only
        case {'force3','force6'}
            if isempty(recordTypeLocked)
                recordTypeLocked = recordType;
                if strcmp(recordTypeLocked,'force6')
                    fprintf(fid,['Timestamp,LeftFz,RightFz,' ...
                        'LeftStepCount,RightStepCount,Phase\n']);
                else
                    fprintf(fid,'Timestamp,LeftFz,RightFz\n');
                end
            end
            if ~strcmp(recordType,recordTypeLocked)
                numMalformed = numMalformed + 1; % field count changed
                continue;                        % mid-run; skip it
            end
        otherwise
            numMalformed = numMalformed + 1;
            if numMalformed == 1 ...
                    || mod(numMalformed,intervalMalformedWarn) == 0
                fprintf(['Warning: could not parse data (x%d so ' ...
                    'far): "%s"\n'],numMalformed,rawLine);
            end
            continue;
        end

        if isempty(timeFirstMs)
            timeFirstMs = nums(1);
        end
        tNow = (nums(1) - timeFirstMs) / msPerSec;

        timeBuf(end+1)  = nums(1); %#ok<SAGROW>
        tBuf(end+1)     = tNow;    %#ok<SAGROW>
        leftBuf(end+1)  = nums(2); %#ok<SAGROW>
        rightBuf(end+1) = nums(3); %#ok<SAGROW>

        % trim buffers to durationPlot
        idx   = tBuf >= tNow - durationPlot;
        tPlot = tBuf(idx);
        lPlot = leftBuf(idx);
        rPlot = rightBuf(idx);

        % update plot data
        set(hLeft,'XData',tPlot,'YData',lPlot);
        set(hRight,'XData',tPlot,'YData',rPlot);

        % dynamic y-axis limits (include the threshold lines so they
        % never fall outside the visible range)
        allY = [lPlot rPlot threshFzUp threshFzDown];
        yMin = min(allY,[],'omitnan');
        yMax = max(allY,[],'omitnan');
        yRange = yMax - yMin;
        if yRange == 0
            margin = 1;
        else
            margin = 0.1 * yRange;
        end
        ylim(hAx,[yMin - margin yMax + margin]);
        xlim(hAx,[max(0,tNow - durationPlot) tNow]);
        drawnow limitrate;

        if strcmp(recordType,'force6')
            fprintf(fid,'%lu,%d,%d,%d,%d,%d\n',nums(1),nums(2), ...
                nums(3),nums(4),nums(5),nums(6));
        else
            fprintf(fid,'%lu,%d,%d\n',nums(1),nums(2),nums(3));
        end
    end

    if isempty(timeBuf)
        warning('No valid force records were logged during this run.');
    else
        printForceSummary(leftBuf,rightBuf,threshFzDown,threshFzUp, ...
            numSDMargin,timeBuf,msPerSec);
        try
            saveas(hFig,plotFile);
            fprintf('Final plot saved to %s\n',plotFile);
        catch
            warning('Could not save plot to %s',plotFile);
        end
    end

    closeArduinoAndFile(portArduino,fid,cmdArduinoStop);
    fprintf('Logging complete. CSV saved to %s\n',outputFile);
catch ME
    closeArduinoAndFile(portArduino,fid,cmdArduinoStop);
    rethrow(ME);
end

%% Local Functions

function [recordType,nums] = parseForceLine(rawLine)
%PARSEFORCELINE Classify and parse one line of Arduino serial output.
%
%   Distinguishes a force-data record (3 or 6 comma-separated fields,
%   depending on firmware build) from a stim-echo record (leading 'S,'
%   or 'D,' tag -- see echoStimRecord() in
%   triggerStimWithGaitStateMachine_SpeedIndependent.ino) and from a
%   malformed line. Tolerating the 6-field form supports a lab-PC build
%   that also streams numStepsL, numStepsR, and phase; the shipped
%   firmware's logForceData() emits only the 3-field form.
%
% Inputs:
%   rawLine - one line of text read from the serial port (terminator
%             already stripped), as returned by readline
%
% Outputs:
%   recordType - 'force3', 'force6', 'echo', or 'invalid'
%   nums - numeric row vector of the parsed force fields (3 or 6
%          elements); empty for 'echo' or 'invalid'
%
% Toolbox Dependencies: None
%
% See also LOGFORCESARDUINOSERIAL.

firstField = '';
if strlength(rawLine) > 0
    firstField = extractBefore(rawLine + ',',',');
end
if any(strcmpi(firstField,{'S','D'}))
    recordType = 'echo';
    nums = [];
    return;
end

nums6 = sscanf(rawLine,'%lu,%d,%d,%d,%d,%d');
if numel(nums6) == 6
    recordType = 'force6';
    nums = nums6';
    return;
end

nums3 = sscanf(rawLine,'%lu,%d,%d');
if numel(nums3) == 3
    recordType = 'force3';
    nums = nums3';
    return;
end

recordType = 'invalid';
nums = [];

end

function closeArduinoAndFile(portArduino,fid,cmdArduinoStop)
%CLOSEARDUINOANDFILE Stop the Arduino state machine and close the CSV.
%
%   Called on both normal completion and error teardown (a script's
%   cleanup object binds to a base-workspace variable and only runs
%   when that variable is cleared, not at script end, so onCleanup is
%   not used here) so the Arduino is never left with its gait-event
%   state machine running and the CSV file handle is never left open.
%   Safe to call against partially initialized state -- an invalid
%   serial object or an unopened file -- since each step is guarded
%   individually. A state machine left running by an interrupted run is
%   harmless: the next cmdArduinoStart resets it, as does a power cycle.
%
% Inputs:
%   portArduino - serialport object connected to the Arduino
%   fid - file identifier from fopen, or -1 if not opened
%   cmdArduinoStop - command byte value that stops the Arduino state
%             machine (must match the frozen serial protocol)
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also LOGFORCESARDUINOSERIAL.

if isvalid(portArduino)
    try
        write(portArduino,cmdArduinoStop,'uint8');
        flush(portArduino);
    catch
        warning('Could not cleanly stop the Arduino state machine.');
    end
    delete(portArduino);
end
if fid ~= -1
    fclose(fid);
end

end

function printForceSummary(leftBuf,rightBuf,threshFzDown,threshFzUp, ...
    numSDMargin,timeBuf,msPerSec)
%PRINTFORCESUMMARY Report signal-quality metrics for this bench run.
%
%   Answers the question this script exists to answer: is the force
%   signal clean enough to drive the Arduino's gait-event state
%   machine? Baseline noise is computed only from samples below
%   threshFzDown -- the firmware's own swing-phase criterion -- so the
%   metric stays commensurable with the threshold it is compared
%   against; selecting the "quietest" samples by amplitude instead
%   would bias the estimated sd low, in exactly the direction that
%   makes a noisy plate look acceptable. No filtering or smoothing is
%   applied here or in the firmware (logForceData() streams raw
%   analogRead values, unfiltered), so this reflects exactly what the
%   state machine sees.
%
% Inputs:
%   leftBuf - 1xN raw left Fz samples (bits)
%   rightBuf - 1xN raw right Fz samples (bits)
%   threshFzDown - firmware's stance-exit threshold (bits); must match
%             threshFzDown in the .ino
%   threshFzUp - firmware's stance-entry threshold (bits); must match
%             threshFzUp in the .ino
%   numSDMargin - conservative multiplier applied to the baseline sd
%             when computing the margin to threshFzUp
%   timeBuf - 1xN raw Arduino millis() timestamps, used to report the
%             achieved sample rate
%   msPerSec - unit conversion constant (1000)
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also LOGFORCESARDUINOSERIAL.

nominalRateHz = 200; % logForceData()'s intervalLog = 5 ms in the .ino
durationSampledSec = (timeBuf(end) - timeBuf(1)) / msPerSec;
if durationSampledSec > 0
    achievedRateHz = (numel(timeBuf) - 1) / durationSampledSec;
else
    achievedRateHz = NaN;
end

fprintf('\n--- Force Signal Summary ---\n');
fprintf('Achieved sample rate: %.1f Hz (nominal %.0f Hz)\n', ...
    achievedRateHz,nominalRateHz);

legLabels = {'Left','Right'};
legBufs   = {leftBuf,rightBuf};
for legIdx = 1:numel(legBufs)
    buf = legBufs{legIdx};
    baseline = buf(buf < threshFzDown);
    if isempty(baseline)
        fprintf(['%s leg: no samples below threshFzDown (%d) -- ' ...
            'signal may never reach swing baseline\n'], ...
            legLabels{legIdx},threshFzDown);
        continue;
    end
    baselineMean = mean(baseline,'omitnan');
    baselineSD   = std(baseline,'omitnan');
    baselinePP   = max(baseline,[],'omitnan') ...
        - min(baseline,[],'omitnan');
    peakStance   = max(buf,[],'omitnan');
    marginBits   = threshFzUp - (baselineMean + numSDMargin * baselineSD);
    fprintf(['%s leg: baseline %.1f +/- %.1f bits (peak-to-peak ' ...
        '%.0f), peak stance %.0f bits, margin to threshFzUp (%d) ' ...
        '= %.1f bits\n'],legLabels{legIdx},baselineMean,baselineSD, ...
        baselinePP,peakStance,threshFzUp,marginBits);
end

end
