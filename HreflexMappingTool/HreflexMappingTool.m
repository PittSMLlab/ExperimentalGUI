%% HreflexMappingTool.m
% ------------------------------------------------------------------------
% Live H-reflex electrode-placement mapping tool.
%
% PURPOSE
%   Stream EMG from Vicon (via the DataStream SDK), watch the Tibialis
%   Anterior (TA) channel for the stimulation artifact, and on each detected
%   stimulus grab a 100 ms window (10 ms pre-artifact to 90 ms post) of TA
%   and Soleus (SOL) EMG. Each trial is plotted in a screen location that
%   matches the electrode position (center/left/up/right/down) so multiple
%   stimulation sites can be compared at a glance. The Soleus M-wave and
%   H-reflex peaks are found automatically and annotated with:
%       (1) artifact -> H-reflex peak latency (ms)
%       (2) M-wave   -> H-reflex peak latency (ms)
%
% HARDWARE / SOFTWARE ASSUMPTIONS
%   - Stimulator : Digitimer DS8R + bar electrode (no separate sync/trigger
%                  channel in Vicon -> artifact detected from TA EMG).
%   - Recording  : Delsys Trigno via Vicon. EMG effective rate 2000 Hz,
%                  streamed as sub-samples inside 100 Hz Vicon frames.
%   - Vicon device name = 'EMG', output name = 'Sensor #',
%     output component  = 'IM EMG#'   (# = the sensor number you enter).
%   - MATLAB r2021a, DataStream SDK v1.11, Win64.
%
% DETECTION / TIMING DEFAULTS (all tunable in the CONFIG block below)
%   - Adaptive artifact threshold on raw TA (robust median/MAD baseline),
%     gated by a rising-edge (derivative) criterion to reject volitional TA
%     bursts during walking.
%   - Soleus M-wave search window : 5-22 ms after the artifact.
%   - Soleus H-reflex search window: 25-65 ms after the artifact
%     (deliberately wide; the soleus H-reflex interval is ~35-50 ms
%     post-stimulus per Thompson et al., Front. Rehabil. Sci. 2022).
%   - Display band-pass: 10-500 Hz, zero-phase (Signal Processing Toolbox).
%
% NOTE ON UNITS
%   EMG amplitude is plotted in whatever units Vicon streams (device scaling
%   dependent, typically volts for Trigno). Axes are labelled "EMG (units)".
%
% REQUIRES: Signal Processing Toolbox for band-pass filtering. If absent,
%           the script falls back to DC removal only and warns.
% ------------------------------------------------------------------------

clearvars;
close all;

%% ======================= CONFIG ========================================
cfg = struct();

% --- Connection / SDK ---------------------------------------------------
cfg.HostName   = 'localhost:801';
cfg.SDKPath    = 'C:\Program Files\Vicon\DataStream SDK\Win64';
cfg.SDKAssembly= 'ViconDataStreamSDK_DotNET.dll';
cfg.DeviceName = 'EMG';                 % Vicon device name for the EMG system

% --- Acquisition timing -------------------------------------------------
cfg.fsNominal  = 2000;                  % expected EMG rate (Hz); actual is measured
cfg.preMs      = 10;                    % window start, before artifact (ms)
cfg.postMs     = 90;                    % window end, after artifact (ms)

% --- Artifact detection (on RAW TA) ------------------------------------
cfg.baselineMs = 200;                   % trailing window for baseline stats (ms)
cfg.guardMs    = 5;                     % gap between baseline window and "now" (ms)
cfg.kAmp       = 8;                      % amplitude threshold = median + kAmp*sigma
cfg.kDeriv     = 6;                      % rising-edge threshold = kDeriv*sigma(diff)
cfg.absFloor   = [];                     % optional absolute |TA| floor (units); [] = off
cfg.timeoutS   = 120;                    % give up watching after this many seconds

% --- Peak search windows (ms after artifact) ---------------------------
cfg.MwinMs     = [5  22];               % Soleus M-wave search window
cfg.HwinMs     = [25 65];               % Soleus H-reflex search window (wide)
cfg.mPresentFactor = 3;                 % M-wave "present" if its p2p > factor*noise p2p

% --- Display filtering --------------------------------------------------
cfg.bpBand     = [10 500];              % band-pass for display/peak-picking (Hz)
cfg.bpOrder    = 4;                     % Butterworth order

% --- Screen layout ------------------------------------------------------
cfg.figFracW   = 0.32;                  % each figure width  as fraction of screen
cfg.figFracH   = 0.30;                  % each figure height as fraction of screen
                                        % (kept short so the Up/Center/Down
                                        % column does not overlap; also hard-
                                        % clamped to fit 3 stacked figures)
cfg.dialogMarginPx = 20;                % gap from the top-right screen corner (px)

cfg.sites      = {'Center','Left','Up','Right','Down'};

% --- DS8R stimulator (Digitimer COM API) -------------------------------
cfg.useDS8R       = true;                 % true: MATLAB triggers the DS8R.
                                          % false (or COM unavailable): revert
                                          % to MANUAL triggering (experimenter
                                          % fires the pulse by hand/pedal).
cfg.ds8rProgID    = 'DigitimerDS8R.DS8RController';
cfg.confirmEachStim = true;               % require a click to confirm before each pulse
cfg.startDemand_mA  = 5;                  % default starting stimulus current (mA)
cfg.maxDemand_mA    = 50;                 % SOFTWARE safety cap on stimulus current (mA).
                                          % Set this to your protocol/ethics ceiling.
cfg.pulseWidth_us   = 1000;               % stimulus pulse width (us); 1 ms typical H-reflex.
                                          % [] = leave whatever the DS8R is set to.
cfg.recovery_pct    = [];                 % [] = leave device setting (biphasic only)
cfg.dwell_us        = [];                 % [] = leave device setting
%% ======================================================================

%% ----- Prompt for leg, then the save folder --------------------------
% The protocol runs once per leg, so keep the two legs in separate folders.
leg = choiceDialogTR(cfg, 'Which leg is being tested?', 'Leg under test', {'Left','Right'});
if isempty(leg)
    fprintf('Cancelled at leg selection. Exiting.\n'); return;
end
% Ask once for a parent folder; create "<Leg>NerveLocalization" in it.
saveDir = ensureNLFolder(leg);   % '' if the user cancels (nothing saved)

%% ----- Prompt for sensor numbers --------------------------------------
[answ, ok] = inputDialogTR(cfg, ...
    {'TA (Tibialis Anterior) sensor number:', ...
     'SOL (Soleus) sensor number:'}, ...
    'EMG sensor assignment', {'1','2'});
if ~ok
    fprintf('Cancelled at sensor entry. Exiting.\n'); return;
end
taNum  = str2double(answ{1});
solNum = str2double(answ{2});
if any(isnan([taNum solNum])) || any([taNum solNum] < 1)
    error('Sensor numbers must be positive integers.');
end

ch.TA.output  = sprintf('Sensor %d', taNum);
ch.TA.comp    = sprintf('IM EMG%d', taNum);
ch.SOL.output = sprintf('Sensor %d', solNum);
ch.SOL.comp   = sprintf('IM EMG%d', solNum);
fprintf('TA : %s / %s\nSOL: %s / %s\n', ch.TA.output, ch.TA.comp, ...
        ch.SOL.output, ch.SOL.comp);

%% ----- Load SDK & connect ---------------------------------------------
MyClient = connectVicon(cfg);
cleanupObj = onCleanup(@() safeDisconnect(MyClient));  % disconnect on exit/error

%% ----- Measure effective EMG rate -------------------------------------
fs = measureRate(MyClient, cfg, ch);
fprintf('Measured EMG rate: %g Hz (%d sub-samples/frame).\n', fs, round(fs/getFrameRate(MyClient)));
if abs(fs - cfg.fsNominal) > 0.05*cfg.fsNominal
    warning('Measured EMG rate (%g Hz) differs from nominal (%g Hz). Using measured value.', ...
            fs, cfg.fsNominal);
end

%% ----- Precompute screen positions & filter ---------------------------
figPos   = sitePositions(cfg);          % struct: figPos.(site) = [x y w h]
figMap   = struct();                    % will hold one figure handle per site
bp       = designBandpass(fs, cfg);     % filter coefficients (or [] if no toolbox)

%% ----- Connect the DS8R stimulator ------------------------------------
stim = connectDS8R(cfg);                % [] if manual / unavailable
stimCleanup = onCleanup(@() safeStim(stim));   % disable output & release on exit/error
lastDemand_mA = cfg.startDemand_mA;

%% ----- Initialise the per-trial log -----------------------------------
% One CSV and one MAT per session, written to the same "Nerve Localization"
% folder and rewritten after every trial (crash-resilient). The MAT also
% stores the raw + filtered windows for later re-analysis.
sessionTag = datestr(now,'yyyymmdd_HHMMSS');
csvPath = ''; matPath = '';
if ~isempty(saveDir)
    stem = sprintf('%sNerveLocalization_log_%s', leg, sessionTag);
    csvPath = fullfile(saveDir, [stem '.csv']);
    matPath = fullfile(saveDir, [stem '.mat']);
    fprintf('Trial log: %s(.csv/.mat)\n', fullfile(saveDir, stem));
end
session = buildSession(sessionTag, fs, ch, cfg, saveDir, leg);
trials  = emptyTrials();                 % struct array, appended per trial

%% ----- Main loop: pick a site, set intensity, stimulate, capture, plot -
if isempty(stim)
    fprintf('\nReady (MANUAL trigger). Pick a site, deliver ONE stimulation, inspect, repeat.\n');
else
    fprintf('\nReady (DS8R serial %d). Pick a site, set intensity, stimulate, inspect, repeat.\n', stim.serial);
end
while true
    site = choiceDialogTR(cfg, 'Select stimulation site to record:', 'Stimulation site', ...
                          [cfg.sites, {'--- Finish ---'}]);
    if isempty(site) || strcmp(site,'--- Finish ---')
        break;   % Finish / cancelled
    end

    % --- Determine intensity & build the trigger action --------------------
    demand_mA = NaN;
    if isempty(stim)
        triggerFcn = [];                       % experimenter fires manually
    else
        [a, ok] = inputDialogTR(cfg, {sprintf('Stimulus current for %s (mA), max %g:', site, cfg.maxDemand_mA)}, ...
                                'Stimulus intensity', {num2str(lastDemand_mA)});
        if ~ok, continue; end                  % cancelled -> back to site menu
        demand_mA = str2double(a{1});
        if isnan(demand_mA) || demand_mA < 0
            warning('Invalid current; skipping.'); continue;
        end
        [demand_uA, demand_mA] = clampDemand(demand_mA, cfg);   % enforce software cap
        lastDemand_mA = demand_mA;

        if cfg.confirmEachStim
            q = choiceDialogTR(cfg, sprintf(['Site: %s\nCurrent: %.2f mA\nPulse width: %s\n\n' ...
                          'Arm the recorder and STIMULATE?'], site, demand_mA, pwStr(cfg)), ...
                          'Confirm stimulation', {'Stimulate','Cancel'});
            if ~strcmp(q,'Stimulate'), continue; end
        end
        setStim(stim, cfg, demand_uA);         % push current + pulse width, enable output
        triggerFcn = @() fireStim(stim);       % fired once the recorder is armed
    end

    % Create or raise this site's figure in its screen location
    figMap.(site) = ensureFigure(figMap, site, figPos.(site));
    showArmed(figMap.(site), site);

    % Arm the detector, fire the pulse (auto mode), and capture the window
    cap = captureOneStim(MyClient, ch, cfg, fs, site, triggerFcn);
    if ~isempty(stim)
        safeDisableOutput(stim);               % leave the device "cold" between trials
    end
    if isempty(cap)
        showAborted(figMap.(site), site);
        continue;   % cancelled or timed out
    end

    % Filter, find peaks, and draw
    trace = processTrace(cap, fs, cfg, bp);
    trace.demand_mA = demand_mA;               % NaN in manual mode
    plotSite(figMap.(site), site, trace, cfg);

    % Save Center trials to disk (.fig + .png) for the localization record.
    savedImg = '';
    if strcmpi(site,'Center') && ~isempty(saveDir)
        savedImg = saveCenterFigure(figMap.(site), saveDir, demand_mA);
    end

    % Append this trial to the CSV + MAT log (all sites).
    if ~isempty(saveDir)
        trials = logTrial(trials, csvPath, matPath, session, ...
                          site, demand_mA, cfg, fs, trace, cap, savedImg);
    end

    fprintf('[%s] I = %s mA | artifact->H = %.1f ms | M->H = %s | H p2p = %.4g | M p2p = %.4g\n', ...
        site, iStr(demand_mA), trace.tH, latStr(trace.tHfromM), trace.Hp2p, trace.Mp2p);
end

fprintf('\nFinished. %d site figure(s) left open for comparison.\n', numel(fieldnames(figMap)));
if ~isempty(saveDir)
    fprintf('Logged %d trial(s) to %s(.csv/.mat).\n', numel(trials), ...
            fullfile(saveDir, sprintf('%sNerveLocalization_log_%s', leg, sessionTag)));
end
% Disconnect now (onCleanup only fires on error or when the script's variables
% are cleared, which does not happen on normal completion in a script).
safeStim(stim);
safeDisconnect(MyClient);
% Figures remain open.


%% ======================= LOCAL FUNCTIONS ==============================

function MyClient = connectVicon(cfg)
% Load the .NET assembly and open a direct connection.
    fprintf('Loading Vicon DataStream SDK ...');
    asm = fullfile(cfg.SDKPath, cfg.SDKAssembly);
    if exist(asm,'file') ~= 2
        % Fall back to MATLAB path, then to a file picker.
        onPath = which(cfg.SDKAssembly);
        if ~isempty(onPath)
            asm = onPath;
        else
            [f,p] = uigetfile('*.dll','Locate ViconDataStreamSDK_DotNET.dll');
            if isequal(f,0), error('SDK assembly not found; cannot continue.'); end
            asm = fullfile(p,f);
        end
    end
    NET.addAssembly(asm);
    fprintf(' done.\n');

    MyClient = ViconDataStreamSDK.DotNET.Client();
    fprintf('Connecting to %s ', cfg.HostName);
    tConn = tic;
    while ~MyClient.IsConnected().Connected
        MyClient.Connect(cfg.HostName);
        fprintf('.');
        if toc(tConn) > 30
            error('Could not connect to Vicon at %s within 30 s.', cfg.HostName);
        end
        pause(0.05);
    end
    fprintf(' connected.\n');

    MyClient.EnableDeviceData();
    MyClient.SetBufferSize(1);
    MyClient.SetStreamMode(ViconDataStreamSDK.DotNET.StreamMode.ClientPull);
end

function safeDisconnect(MyClient)
    try
        if ~isempty(MyClient) && MyClient.IsConnected().Connected
            MyClient.Disconnect();
            fprintf('Disconnected from Vicon.\n');
        end
    catch
        % ignore errors during teardown
    end
end

%% ---------- DS8R stimulator (Digitimer COM API) -----------------------

function stim = connectDS8R(cfg)
% Start the DS8R COM server and grab the first device. Returns a struct
% with .controller .serial, or [] to fall back to MANUAL triggering.
    stim = [];
    if ~cfg.useDS8R
        fprintf('DS8R control disabled in config: MANUAL triggering.\n');
        return;
    end
    try
        ctl = actxserver(cfg.ds8rProgID);
    catch ME
        warning(['Could not start the DS8R COM server (%s). Is the DS8R software ' ...
                 'installed? Falling back to MANUAL triggering.'], ME.message);
        return;
    end
    % The server inventories devices on creation; poll GetState briefly.
    count = 0; t0 = tic;
    while toc(t0) < 5
        try
            col = ctl.GetState; count = double(col.Count);
        catch
            count = 0;
        end
        if count > 0, break; end
        pause(0.1);
    end
    if count < 1
        warning('DS8R COM server started but found no device. Falling back to MANUAL triggering.');
        try, delete(ctl); catch, end
        return;
    end
    st = col.Items(0);
    stim = struct();
    stim.controller = ctl;
    stim.serial     = double(st.SerialNumber);
    fprintf('DS8R connected (serial %d).\n', stim.serial);
    % Show the pulse-shape parameters that stay under device/software control,
    % so the experimenter can confirm the unit is configured as expected.
    try
        fprintf(['  Device settings: Demand=%g uA, DemandLimit=%g uA, PulseWidth=%g us, ' ...
                 'Recovery=%g%%, Dwell=%g us\n'], double(st.Demand), double(st.DemandLimit), ...
                 double(st.PulseWidth), double(st.Recovery), double(st.Dwell));
    catch
    end
end

function [uA, mA] = clampDemand(mA_in, cfg)
% Enforce the software current cap and the DS8R 100 uA demand resolution.
    mA = min(max(mA_in, 0), cfg.maxDemand_mA);
    uA = round(mA*1000 / 100) * 100;     % nearest 100 uA
    mA = uA/1000;
end

function setStim(stim, cfg, demand_uA)
% Push stimulus current (+ optional pulse width / recovery / dwell) to the
% device and enable output. A fresh state is fetched first, as recommended
% by the API (the state object is a static snapshot).
    col = stim.controller.GetState;
    st  = col.Items(0);
    % Hardware demand limit must be >= 100 mA (API minimum); our finer cap is
    % enforced in software by clampDemand before we get here.
    try, st.DemandLimit = max(cfg.maxDemand_mA*1000, 100000); catch, end
    st.Demand = demand_uA;
    if ~isempty(cfg.pulseWidth_us), st.PulseWidth = cfg.pulseWidth_us; end
    if ~isempty(cfg.recovery_pct),  st.Recovery   = cfg.recovery_pct;  end
    if ~isempty(cfg.dwell_us),      st.Dwell      = cfg.dwell_us;       end
    st.OutputEnable = true;
    invoke(stim.controller, 'SetState', st, true);   % blocking apply
end

function fireStim(stim)
% Trigger one immediate pulse using the device's currently configured state.
    col = stim.controller.GetState;
    st  = col.Items(0);
    invoke(st, 'Trigger');
end

function safeDisableOutput(stim)
% Disable the DS8R output (leave the device "cold") without releasing it.
    if isempty(stim), return; end
    try
        col = stim.controller.GetState;
        st  = col.Items(0);
        st.OutputEnable = false;
        invoke(stim.controller, 'SetState', st, true);
    catch
    end
end

function safeStim(stim)
% Disable output and release the COM server. Safe to call with [] or twice.
    if isempty(stim), return; end
    safeDisableOutput(stim);
    try
        delete(stim.controller);
        fprintf('DS8R output disabled and COM server released.\n');
    catch
    end
end

%% ---------- Save folder & Center-plot saving --------------------------

function saveDir = ensureNLFolder(leg)
% Ask for a parent folder and create "<Leg>NerveLocalization" inside it.
% Returns '' if the user cancels (nothing is then saved).
    saveDir = '';
    folderName = sprintf('%sNerveLocalization', leg);
    parent = uigetdir(pwd, sprintf('Select the folder in which to create the "%s" folder', folderName));
    if isequal(parent, 0)
        warning('No save folder selected: nothing will be saved this session.');
        return;
    end
    d = fullfile(parent, folderName);
    if exist(d, 'dir') ~= 7
        [ok, msg] = mkdir(d);
        if ~ok
            warning('Could not create "%s" (%s). Nothing will be saved.', d, msg);
            return;
        end
    end
    saveDir = d;
    fprintf('Saving to: %s\n', saveDir);
end

function base = saveCenterFigure(f, saveDir, demand_mA)
% Save a Center trial as both .fig and .png, uniquely named by timestamp
% (and current, when known) so repeated Center trials do not overwrite.
% Returns the base filename (no extension), or '' on failure.
    if isnan(demand_mA), iTag = 'NA';
    else, iTag = strrep(sprintf('%.2fmA', demand_mA), '.', 'p'); end
    base = sprintf('Center_%s_%s', datestr(now,'yyyymmdd_HHMMSS'), iTag);
    figPath = fullfile(saveDir, [base '.fig']);
    pngPath = fullfile(saveDir, [base '.png']);
    try
        savefig(f, figPath);
        print(f, pngPath, '-dpng', '-r150');
        fprintf('Saved Center trial: %s(.fig/.png)\n', fullfile(saveDir, base));
    catch ME
        warning('Could not save Center figure (%s).', ME.message);
        base = '';
    end
end

%% ---------- Per-trial logging (CSV + MAT) -----------------------------

function session = buildSession(sessionTag, fs, ch, cfg, saveDir, leg)
% Session-level metadata stored alongside the trials in the MAT file.
    session = struct();
    session.SessionStart = sessionTag;
    session.Leg          = leg;
    session.Fs_Hz        = fs;
    session.TA_output    = ch.TA.output;   session.TA_component  = ch.TA.comp;
    session.SOL_output   = ch.SOL.output;  session.SOL_component = ch.SOL.comp;
    session.PulseWidth_us = cfg.pulseWidth_us;
    session.MaxDemand_mA  = cfg.maxDemand_mA;
    session.PreMs = cfg.preMs;  session.PostMs = cfg.postMs;
    session.MwinMs = cfg.MwinMs; session.HwinMs = cfg.HwinMs;
    session.BandpassHz = cfg.bpBand;
    session.SaveDir = saveDir;
end

function trials = emptyTrials()
% Return a 0x0 struct with the trial fields defined (so appends are uniform).
    f = {'Trial','Timestamp','Leg','Site','Current_mA','PulseWidth_us','Fs_Hz', ...
         'ArtifactToM_ms','ArtifactToH_ms','MToH_ms', ...
         'M_peak','M_p2p','H_peak','H_p2p','M_present','FrameGap','SavedImage', ...
         't_ms','TA_filt','SOL_filt','TA_raw','SOL_raw'};
    args = [f; repmat({{}},1,numel(f))];
    trials = struct(args{:});
    trials = trials([]);   % make it 0x0 but with the fields
end

function trials = logTrial(trials, csvPath, matPath, session, ...
                           site, demand_mA, cfg, fs, trace, cap, savedImg)
% Append one trial and rewrite both the CSV (summary) and MAT (full) files.
    n = numel(trials) + 1;
    r = struct();
    r.Trial          = n;
    r.Timestamp      = datestr(now,'yyyy-mm-dd HH:MM:SS');
    r.Leg            = session.Leg;
    r.Site           = site;
    r.Current_mA     = demand_mA;                       % NaN in manual mode
    r.PulseWidth_us  = valOrNaN(cfg.pulseWidth_us);
    r.Fs_Hz          = fs;
    r.ArtifactToM_ms = iff(trace.mPresent, trace.M.tPk, NaN);
    r.ArtifactToH_ms = trace.tH;
    r.MToH_ms        = trace.tHfromM;                   % NaN if M absent
    r.M_peak         = trace.M.vPk;
    r.M_p2p          = trace.Mp2p;
    r.H_peak         = trace.H.vPk;
    r.H_p2p          = trace.Hp2p;
    r.M_present      = double(trace.mPresent);
    r.FrameGap       = double(trace.gap);
    r.SavedImage     = savedImg;
    % Waveforms (MAT only) — column vectors
    r.t_ms   = trace.t(:).';
    r.TA_filt= trace.TAf(:).';
    r.SOL_filt=trace.SLf(:).';
    r.TA_raw = cap.TA(:).';
    r.SOL_raw= cap.SOL(:).';

    if isempty(trials), trials = r; else, trials(n) = r; end

    % --- rewrite CSV (summary columns only) ---
    if ~isempty(csvPath)
        try
            summ = rmfield(trials, {'t_ms','TA_filt','SOL_filt','TA_raw','SOL_raw'});
            writetable(struct2table(summ,'AsArray',true), csvPath);
        catch ME
            warning(['Could not write CSV (%s). If it is open in another program ' ...
                     '(e.g. Excel), close it; the log will update on the next trial.'], ME.message);
        end
    end
    % --- rewrite MAT (full record) ---
    if ~isempty(matPath)
        try
            save(matPath, 'trials', 'session');
        catch ME
            warning('Could not write MAT (%s).', ME.message);
        end
    end
end

function y = valOrNaN(x)
    if isempty(x), y = NaN; else, y = x; end
end

%% ---------- Custom dialogs anchored top-right -------------------------
% MATLAB's built-in dialogs open screen-centered and cover the Center plot.
% Repositioning them after the fact was unreliable (it races their layout),
% so we build our own modal windows and set their position AT CREATION.

function [x, y, W, H] = topRightBox(cfg, W, H)
% Top-left pixel origin for a WxH window in the screen's top-right corner.
    sc = get(0,'ScreenSize');
    x = max(sc(3) - W - cfg.dialogMarginPx, 1);
    y = max(sc(4) - H - cfg.dialogMarginPx, 1);
end

function [vals, ok] = inputDialogTR(cfg, prompts, titleStr, defaults)
% Modal multi-field text-entry dialog, anchored top-right.
% Returns vals (cellstr, one per prompt) and ok (true if OK/Enter pressed).
    prompts = cellstr(prompts);
    n = numel(prompts);
    ok = false; vals = repmat({''}, 1, n);
    rowH = 50; padTop = 16; padBot = 50; W = 340;
    H = padTop + n*rowH + padBot;
    [x, y] = topRightBox(cfg, W, H);
    f = figure('Name',titleStr,'NumberTitle','off','MenuBar','none','ToolBar','none', ...
               'Units','pixels','Position',[x y W H],'Resize','off','WindowStyle','modal', ...
               'Color',get(0,'defaultUicontrolBackgroundColor'),'Tag','HreflexDialog', ...
               'CloseRequestFcn',@(s,~) onCancel());
    edits = gobjects(1,n);
    for i = 1:n
        yTop = H - padTop - (i-1)*rowH;
        uicontrol(f,'Style','text','Units','pixels','Position',[16 yTop-16 W-32 16], ...
                  'String',prompts{i},'HorizontalAlignment','left');
        d = ''; if nargin >= 4 && numel(defaults) >= i, d = defaults{i}; end
        edits(i) = uicontrol(f,'Style','edit','Units','pixels','Position',[16 yTop-40 W-32 24], ...
                  'String',d,'HorizontalAlignment','left','BackgroundColor','w', ...
                  'Callback',@(s,~) onOK());   % Enter in a field = OK
    end
    uicontrol(f,'Style','pushbutton','String','OK','Units','pixels', ...
              'Position',[W-172 12 74 30],'Callback',@(s,~) onOK());
    uicontrol(f,'Style','pushbutton','String','Cancel','Units','pixels', ...
              'Position',[W-90 12 74 30],'Callback',@(s,~) onCancel());
    uicontrol(edits(1));            % focus the first field
    uiwait(f);
    if ishandle(f), delete(f); end

    function onOK()
        for k = 1:n, vals{k} = get(edits(k),'String'); end
        ok = true; uiresume(f);
    end
    function onCancel()
        ok = false; uiresume(f);
    end
end

function choice = choiceDialogTR(cfg, prompt, titleStr, options)
% Modal single-choice dialog (one button per option), anchored top-right.
% Returns the chosen option string, or '' if cancelled/closed.
    options = cellstr(options);
    m = numel(options);
    choice = '';
    lines = strsplit(prompt, sprintf('\n'));
    nL = numel(lines);
    W = 300; btnH = 30; btnGap = 8; padTop = 14; promptH = nL*16 + 10; padBot = 14;
    H = padTop + promptH + 8 + m*(btnH+btnGap) + padBot;
    [x, y] = topRightBox(cfg, W, H);
    f = figure('Name',titleStr,'NumberTitle','off','MenuBar','none','ToolBar','none', ...
               'Units','pixels','Position',[x y W H],'Resize','off','WindowStyle','modal', ...
               'Color',get(0,'defaultUicontrolBackgroundColor'),'Tag','HreflexDialog', ...
               'CloseRequestFcn',@(s,~) onClose());
    uicontrol(f,'Style','text','Units','pixels', ...
              'Position',[16 H-padTop-promptH W-32 promptH], ...
              'String',lines,'HorizontalAlignment','left');
    yb = H - padTop - promptH - 8 - btnH;
    for i = 1:m
        uicontrol(f,'Style','pushbutton','String',options{i},'Units','pixels', ...
                  'Position',[40 yb W-80 btnH],'Callback',@(s,~) onPick(options{i}));
        yb = yb - (btnH + btnGap);
    end
    uiwait(f);
    if ishandle(f), delete(f); end

    function onPick(s)
        choice = s; uiresume(f);
    end
    function onClose()
        choice = ''; uiresume(f);
    end
end

function h = waitBoxTR(cfg, msg)
% Non-modal status window with a Cancel button, anchored top-right.
% Closing it (Cancel or the window X) is how the caller detects cancellation.
    lines = strsplit(msg, sprintf('\n'));
    W = 330; H = 44 + numel(lines)*16 + 20;
    [x, y] = topRightBox(cfg, W, H);
    h = figure('Name','Waiting for stimulus','NumberTitle','off','MenuBar','none', ...
               'ToolBar','none','Units','pixels','Position',[x y W H],'Resize','off', ...
               'Color',get(0,'defaultUicontrolBackgroundColor'),'Tag','HreflexWait');
    uicontrol(h,'Style','text','Units','pixels','Position',[14 44 W-28 H-56], ...
              'String',lines,'HorizontalAlignment','left');
    uicontrol(h,'Style','pushbutton','String','Cancel','Units','pixels', ...
              'Position',[W-90 10 76 26],'Callback',@(s,~) delete(h));
    drawnow;
end


function r = getFrameRate(MyClient)
    r = double(MyClient.GetFrameRate().FrameRateHz);
    if r <= 0, r = 100; end   % sensible fallback
end

function fs = measureRate(MyClient, cfg, ch)
% Wait until the stream actually reports devices, then count TA sub-samples
% to derive the EMG rate. After a fresh connect the first Success frame(s)
% often carry no device metadata yet, so we must not query too early.
    waitForDevices(MyClient, 15);

    % Devices are present; now the named EMG channel must resolve.
    tGF = tic;
    while true
        MyClient.GetFrame();
        out = MyClient.GetDeviceOutputSubsamples(cfg.DeviceName, ch.TA.output, ch.TA.comp);
        if out.Result == ViconDataStreamSDK.DotNET.Result.Success ...
                && double(out.DeviceOutputSubsamples) >= 1
            break;
        end
        if toc(tGF) > 10
            error(['Devices are streaming, but "%s" / "%s" / "%s" did not resolve. ' ...
                   'Check the device name and the TA sensor number, and confirm the ' ...
                   'channel is visible in the Vicon server device list.'], ...
                   cfg.DeviceName, ch.TA.output, ch.TA.comp);
        end
        pause(0.02);
    end
    nsub = double(out.DeviceOutputSubsamples);
    fs = getFrameRate(MyClient) * nsub;
end

function waitForDevices(MyClient, timeoutS)
% Pull frames until the server reports at least one device, or time out.
    tw = tic;
    while true
        if MyClient.GetFrame().Result == ViconDataStreamSDK.DotNET.Result.Success ...
                && double(MyClient.GetDeviceCount().DeviceCount) > 0
            return;
        end
        if toc(tw) > timeoutS
            error(['Connected to Vicon, but no devices appeared in the stream within %g s.\n' ...
                   '  1) Confirm the Vicon server (Nexus/Tracker) is in Live mode and streaming.\n' ...
                   '  2) Confirm the EMG device is present in the server''s device list.\n' ...
                   '  3) Rule out a leftover DataStream client from a previous run: ' ...
                   'run "clear all" or restart MATLAB, then try again.'], timeoutS);
        end
        pause(0.02);
    end
end

function v = getChannelSamples(MyClient, device, output, comp, nsub)
% Return the nsub sub-samples (temporal order) for one channel in the
% CURRENT frame as a column vector.
    v = zeros(nsub,1);
    for s = 0:nsub-1
        o = MyClient.GetDeviceOutputValue(device, output, comp, uint32(s));
        v(s+1) = double(o.Value);   % Occluded samples come back as 0
    end
end

function cap = captureOneStim(MyClient, ch, cfg, fs, site, triggerFcn)
% Watch raw TA for the stimulation artifact, then collect the full window.
% If triggerFcn is a function handle, it is called ONCE (to fire the DS8R)
% as soon as the recorder is armed with a valid pre-stimulus baseline; if it
% is empty, the experimenter is expected to trigger the pulse manually.
% Returns struct with .TA .SOL (column vectors), .t (ms, 0 = artifact),
% .i0 (artifact index in buffer), .gap (logical: frame gap in window).
% Returns [] if cancelled or timed out.

    nPre  = round(cfg.preMs /1000*fs);
    nPost = round(cfg.postMs/1000*fs);
    Lb    = round(cfg.baselineMs/1000*fs);
    guard = round(cfg.guardMs  /1000*fs);
    needBaseline = Lb + guard + nPre;    % samples required before we start watching

    autoTrig = ~isempty(triggerFcn);
    triggered = false;
    tTrigger  = [];

    % Growing buffers
    bufTA = []; bufSL = []; frameOf = [];   % frameOf(k) = Vicon frame number of sample k
    lastFrame = [];
    i0 = [];                                 % artifact index (into buffers)
    state = 'baseline';

    if autoTrig
        msg = sprintf('Site "%s": arming recorder, then stimulating...\nClose this box to cancel.', site);
    else
        msg = sprintf('Recording site "%s".\nDeliver ONE stimulation.\nClose this box to cancel.', site);
    end
    stopBox = waitBoxTR(cfg, msg);
    tStart = tic;

    while true
        if ~ishandle(stopBox)          % user cancelled
            cap = []; return;
        end
        if toc(tStart) > cfg.timeoutS
            if ishandle(stopBox), delete(stopBox); end
            if autoTrig && triggered
                warning(['No stimulation artifact detected after triggering at "%s". ' ...
                         'Check that the DS8R output is enabled and the current is non-zero, ' ...
                         'and that the electrode is connected.'], site);
            else
                warning('Timed out waiting for a stimulus at site "%s".', site);
            end
            cap = []; return;
        end

        % --- pull the next frame ---
        if MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
            drawnow limitrate; continue;
        end
        fn   = double(MyClient.GetFrameNumber().FrameNumber);
        nsub = double(MyClient.GetDeviceOutputSubsamples(cfg.DeviceName, ch.TA.output, ch.TA.comp).DeviceOutputSubsamples);
        if nsub < 1, drawnow limitrate; continue; end

        newTA = getChannelSamples(MyClient, cfg.DeviceName, ch.TA.output, ch.TA.comp, nsub);
        newSL = getChannelSamples(MyClient, cfg.DeviceName, ch.SOL.output, ch.SOL.comp, nsub);

        prevN = numel(bufTA);
        bufTA = [bufTA; newTA];  bufSL = [bufSL; newSL]; %#ok<AGROW>
        frameOf = [frameOf; repmat(fn, nsub, 1)];        %#ok<AGROW>
        lastFrame = fn;

        switch state
            case 'baseline'
                if numel(bufTA) >= needBaseline
                    state = 'watch';
                end

            case 'watch'
                % Robust baseline over a trailing window ending 'guard' before now.
                bEnd   = prevN - guard;               % last baseline sample index
                bStart = bEnd - Lb + 1;
                if bStart < 1, drawnow limitrate; continue; end
                base   = bufTA(bStart:bEnd);
                med    = median(base);
                sigma  = 1.4826*median(abs(base - med)) + eps;
                dbase  = diff(base);
                sigmaD = 1.4826*median(abs(dbase - median(dbase))) + eps;
                thrAmp = cfg.kAmp   * sigma;
                thrDrv = cfg.kDeriv * sigmaD;

                % Recorder is armed with a valid pre-stimulus baseline: fire
                % the pulse now (auto mode), exactly once. The artifact will
                % arrive in a later frame, after the software-trigger latency.
                if autoTrig && ~triggered
                    try
                        triggerFcn();
                    catch ME
                        if ishandle(stopBox), delete(stopBox); end
                        warning('DS8R trigger failed: %s. Aborting this trial.', ME.message);
                        cap = []; return;
                    end
                    triggered = true; tTrigger = tic; %#ok<NASGU>
                end

                % Scan the newly arrived samples (with one-sample lookback for diff).
                scan   = bufTA(prevN:end);            % includes last old sample
                dscan  = abs(diff(scan));
                ampHit = abs(scan(2:end) - med) > thrAmp;
                drvHit = dscan > thrDrv;
                hit    = ampHit & drvHit;
                if ~isempty(cfg.absFloor)
                    hit = hit & (abs(scan(2:end) - med) > cfg.absFloor);
                end
                k = find(hit, 1, 'first');
                if ~isempty(k)
                    i0 = prevN + k;                   % absolute index of artifact
                    state = 'collect';
                end

            case 'collect'
                if numel(bufTA) >= i0 + nPost
                    if ishandle(stopBox), delete(stopBox); end
                    idx = (i0 - nPre):(i0 + nPost);
                    fnWin = frameOf(idx);
                    gap   = ~all(diff(unique(fnWin,'stable')) == 1);
                    cap = struct('TA', bufTA(idx), 'SOL', bufSL(idx), ...
                                 't', ((-nPre:nPost)'/fs*1000), ...
                                 'i0', i0, 'gap', gap);
                    return;
                end
        end
        drawnow limitrate;
    end
end

function bp = designBandpass(fs, cfg)
% Return band-pass coefficients, or [] if the Signal Processing Toolbox
% is unavailable (caller then does DC removal only).
    bp = [];
    if exist('butter','file') == 2 && exist('filtfilt','file') == 2
        Wn = cfg.bpBand / (fs/2);
        Wn = min(max(Wn, 1e-4), 0.999);
        [b,a] = butter(cfg.bpOrder, Wn, 'bandpass');
        bp = struct('b',b,'a',a);
    else
        warning(['Signal Processing Toolbox not found: showing DC-removed ' ...
                 'EMG instead of %g-%g Hz band-pass.'], cfg.bpBand(1), cfg.bpBand(2));
    end
end

function y = filtEMG(x, bp)
    if isempty(bp)
        y = x - mean(x);           % fallback: DC removal only
    else
        y = filtfilt(bp.b, bp.a, x);
    end
end

function trace = processTrace(cap, fs, cfg, bp)
% Filter both channels and locate the Soleus M-wave and H-reflex.
    t   = cap.t;
    TAf = filtEMG(cap.TA, bp);
    SLf = filtEMG(cap.SOL, bp);

    % Noise reference from the pre-stimulus baseline (start of window .. -1 ms)
    preIdx = t < -1;
    if any(preIdx), noiseP2P = max(SLf(preIdx)) - min(SLf(preIdx));
    else,           noiseP2P = max(SLf) - min(SLf); end

    M = peakInWindow(SLf, t, cfg.MwinMs);
    H = peakInWindow(SLf, t, cfg.HwinMs);

    mPresent = M.p2p > cfg.mPresentFactor * noiseP2P;

    trace = struct();
    trace.t        = t;
    trace.TAf      = TAf;
    trace.SLf      = SLf;
    trace.M        = M;
    trace.H        = H;
    trace.mPresent = mPresent;
    trace.tH       = H.tPk;                    % artifact -> H-reflex peak (ms)
    trace.tHfromM  = iff(mPresent, H.tPk - M.tPk, NaN);  % M-wave -> H peak (ms)
    trace.Hp2p     = H.p2p;
    trace.Mp2p     = M.p2p;
    trace.gap      = cap.gap;
end

function pk = peakInWindow(sig, t, winMs)
% Peak = sample of largest ABSOLUTE amplitude inside the window.
% Also returns peak-to-peak amplitude across the window.
    in = t >= winMs(1) & t <= winMs(2);
    idx = find(in);
    seg = sig(idx);
    [~,imx] = max(abs(seg));
    pk.tPk = t(idx(imx));
    pk.vPk = seg(imx);
    pk.p2p = max(seg) - min(seg);
    pk.win = winMs;
end

%% ---------- Figure placement & drawing --------------------------------

function pos = sitePositions(cfg)
% Build a plus-shaped layout that mirrors electrode movement:
% Up = top of screen, Down = bottom, Left = left, Right = right, Center = middle.
    sc = get(0,'ScreenSize');    % [1 1 W H]
    W = sc(3); H = sc(4);
    w = round(W*cfg.figFracW);
    m = round(min(W,H)*0.02);    % margin
    % Height is hard-clamped so the Up/Center/Down column (3 stacked figures
    % plus margins) always fits the monitor without overlapping.
    hMax = floor((H - 4*m)/3);
    h = min(round(H*cfg.figFracH), hMax);
    cx = round((W - w)/2);
    cy = round((H - h)/2);
    pos.Center = [cx,          cy,        w, h];
    pos.Left   = [m,           cy,        w, h];
    pos.Right  = [W - w - m,   cy,        w, h];
    pos.Up     = [cx,          H - h - m, w, h];
    pos.Down   = [cx,          m,         w, h];
end

function f = ensureFigure(figMap, site, posPix)
% Reuse this site's figure if it exists, else create it at the right spot.
    if isfield(figMap, site) && ishandle(figMap.(site))
        f = figMap.(site);
        clf(f);
    else
        f = figure('Name', sprintf('Site: %s', site), 'NumberTitle','off', ...
                   'Units','pixels', 'Position', posPix, 'Color','w', ...
                   'Tag','HreflexSitePlot');
    end
    figure(f);   % raise
end

function showArmed(f, site)
    clf(f);
    ax = axes('Parent',f); axis(ax,'off');
    text(0.5,0.5, sprintf('ARMED: %s\n\nWaiting for stimulation ...', upper(site)), ...
        'Parent',ax,'HorizontalAlignment','center','FontSize',13,'FontWeight','bold');
    drawnow;
end

function showAborted(f, site)
    if ~ishandle(f), return; end
    clf(f);
    ax = axes('Parent',f); axis(ax,'off');
    text(0.5,0.5, sprintf('%s: capture cancelled / timed out', upper(site)), ...
        'Parent',ax,'HorizontalAlignment','center','FontSize',12,'Color',[0.6 0 0]);
    drawnow;
end

function plotSite(f, site, tr, cfg)
% TA (with artifact) on top, Soleus (with M-wave & H-reflex) below.
    figure(f); clf(f);
    t = tr.t;

    axTA = subplot(2,1,1,'Parent',f);
    plot(axTA, t, tr.TAf, 'Color',[0.15 0.15 0.15]); hold(axTA,'on');
    ylTA = ylim(axTA);
    vline(axTA, 0, ylTA, [1 0 0]);                       % stimulus artifact @ t=0
    if isfield(tr,'demand_mA') && ~isnan(tr.demand_mA)
        titTA = sprintf('%s  —  Tibialis Anterior   (I = %.2f mA)', upper(site), tr.demand_mA);
    else
        titTA = sprintf('%s  —  Tibialis Anterior (detection channel)', upper(site));
    end
    title(axTA, titTA);
    ylabel(axTA, 'EMG (units)'); grid(axTA,'on');
    xlim(axTA, [t(1) t(end)]);

    axSL = subplot(2,1,2,'Parent',f);
    % Plot the Soleus trace first so the y-limits come from the data,
    % then shade the search windows to those limits (patches drawn last
    % would otherwise rescale the axis).
    plot(axSL, t, tr.SLf, 'Color',[0 0 0.55], 'LineWidth',1); hold(axSL,'on');
    yr = max(tr.SLf) - min(tr.SLf); if yr==0, yr=1; end
    yl = [min(tr.SLf) max(tr.SLf)] + 0.25*yr*[-1 1];   % pad for annotation
    ylim(axSL, yl);
    shadeWindow(axSL, cfg.MwinMs, [0.85 0.92 1.00], yl);   % M window (blue-ish)
    shadeWindow(axSL, cfg.HwinMs, [0.90 1.00 0.88], yl);   % H window (green-ish)
    vline(axSL, 0, yl, [1 0 0]);                            % stimulus artifact @ t=0

    % Mark M-wave (if present) and H-reflex peaks.
    if tr.mPresent
        plot(axSL, tr.M.tPk, tr.M.vPk, 'v', 'MarkerFaceColor',[0 0.4 0.8], ...
             'MarkerEdgeColor','k','MarkerSize',8);
        text(axSL, tr.M.tPk, tr.M.vPk, '  M', 'Color',[0 0.4 0.8], ...
             'FontWeight','bold','VerticalAlignment','bottom');
    end
    plot(axSL, tr.H.tPk, tr.H.vPk, '^', 'MarkerFaceColor',[0 0.55 0], ...
         'MarkerEdgeColor','k','MarkerSize',9);

    % Two numbers above the H-reflex peak.
    yTxt = tr.H.vPk + sign(tr.H.vPk + eps)*0.12*yr;
    va = iff(tr.H.vPk >= 0, 'bottom', 'top');
    text(axSL, tr.H.tPk, yTxt, ...
        {sprintf('artifact\\rightarrowH: %.1f ms', tr.tH), ...
         sprintf('M\\rightarrowH: %s ms', latStr(tr.tHfromM))}, ...
        'Color',[0 0.4 0], 'FontWeight','bold','FontSize',10, ...
        'HorizontalAlignment','center','VerticalAlignment',va, ...
        'BackgroundColor',[1 1 1 ], 'EdgeColor',[0 0.4 0], 'Margin',2);

    ttl = sprintf('Soleus  —  H p2p = %.3g   |   M p2p = %.3g%s', ...
                  tr.Hp2p, tr.Mp2p, iff(tr.mPresent,'',' (M-wave weak/absent)'));
    title(axSL, ttl);
    xlabel(axSL, 'Time re: stimulus artifact (ms)');
    ylabel(axSL, 'EMG (units)'); grid(axSL,'on');
    xlim(axSL, [t(1) t(end)]); ylim(axSL, yl);

    if tr.gap
        annotation(f,'textbox',[0.15 0.46 0.7 0.05],'String', ...
            'WARNING: dropped Vicon frame(s) within this window — trace may be discontinuous.', ...
            'Color',[0.7 0 0],'EdgeColor','none','HorizontalAlignment','center', ...
            'FontWeight','bold');
    end

    linkaxes([axTA axSL],'x');
    drawnow;
end

function vline(ax, x, yl, c)
% Version-safe vertical line (avoids xline axes-target syntax on r2021a).
    line(ax, [x x], yl, 'Color', c, 'LineWidth', 1, 'HandleVisibility','off');
end

function shadeWindow(ax, winMs, col, yl)
    p = patch(ax, [winMs(1) winMs(2) winMs(2) winMs(1)], ...
                  [yl(1) yl(1) yl(2) yl(2)], col, ...
                  'EdgeColor','none', 'FaceAlpha',0.6, 'HandleVisibility','off');
    uistack(p,'bottom');   % keep the shading behind the EMG trace
end

%% ---------- small helpers ---------------------------------------------

function s = latStr(x)
    if isnan(x), s = 'n/a'; else, s = sprintf('%.1f', x); end
end

function s = iStr(mA)
    if isnan(mA), s = 'n/a'; else, s = sprintf('%.2f', mA); end
end

function s = pwStr(cfg)
    if isempty(cfg.pulseWidth_us), s = '(device setting)';
    else, s = sprintf('%g us', cfg.pulseWidth_us); end
end

function out = iff(cond, a, b)
    if cond, out = a; else, out = b; end
end
