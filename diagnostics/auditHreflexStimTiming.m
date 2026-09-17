function report = auditHreflexStimTiming(datlogPath, options)
%AUDITHREFLEXSTIMTIMING Audit H-reflex stim-gate timing in a saved datlog.
%
%   Runs the acceptance checks described in
%   studies/SpinalAdapt/README.md's "Validation Before Resuming
%   Collection" section against one saved datlog, so that section's
%   checklist is a runnable tool rather than a set of ad hoc commands.
%   Device-only checks (accounting, drop classification, the on-target
%   metric, loop timing) always run. Ground-truth checks against the
%   matching Vicon capture (stim pulse placement, the Arduino's stride-
%   count deficit, toe-off reference error, true double support) run
%   only when options.C3DPath is given, since they need BTK
%   (btkReadAcquisition) and the C3D's stimulator sync + force-plate
%   analog channels.
%
%   The load-bearing ground-truth check is the Arduino stride-count
%   deficit: diff(ardStep) between consecutive delivered pulses on a leg,
%   compared against how many true single-stance strides that leg
%   actually completed over the same span (from the C3D force plates).
%   Unlike the ardStep-decreased regression sentinel already in
%   NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO (which only catches the counter
%   resetting), this catches the counter silently falling behind -- the
%   failure mode that produced the missed and wrong-stride stims in the
%   2026-09-08 pilot (see studies/SpinalAdapt/README.md). It is what
%   distinguishes a clean session (0 deficit) from that one (15% of
%   strides lost by the firmware's gait-event state machine).
%
%   Left/right force-plate channel identity is auto-detected (not
%   assumed): whichever plate assignment gives higher stim-pulse
%   containment inside that leg's single-stance intervals is used, and a
%   low winning containment (<90%) is flagged rather than silently
%   accepted, since it signals a channel-name or gait-detection problem
%   rather than a genuine timing issue.
%
% Inputs:
%   datlogPath - path to a saved datlog .mat file from
%          NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO (or an equivalent
%          Arduino-timed H-reflex controller), containing a top-level
%          'datlog' struct with stim.L/.R and stim.deviceEcho fields
%   options.C3DPath - path to the matching Vicon C3D capture, for
%          ground-truth gait events and stim pulse times via the
%          stimulator trigger sync analog channels. Optional; ground-
%          truth checks are skipped (report.groundTruth left empty) when
%          omitted. Requires BTK (btkReadAcquisition) on the MATLAB path.
%   options.StimTriggerChannelL - C3D analog channel name for the left
%          stimulator's trigger sync pulse
%   options.StimTriggerChannelR - C3D analog channel name for the right
%          stimulator's trigger sync pulse
%   options.ForcePlateChannel1 - C3D analog channel name for one
%          treadmill force plate's vertical (Z) force; leg identity is
%          auto-detected, so the "1"/"2" labels need not be L/R
%   options.ForcePlateChannel2 - C3D analog channel name for the other
%          treadmill force plate's vertical (Z) force
%   options.StimTriggerThresholdV - volts; rising-edge threshold for the
%          stimulator trigger sync channels (observed baseline < 0.05 V,
%          pulses reach ~4.45 V)
%   options.ForceThresholdN - newtons; stance threshold applied to the
%          C3D force-plate channels, matching
%          NirsHreflexArduinoOpenLoopWithAudio's own robust stance
%          threshold (forcePlateRobustThreshold)
%   options.Verbose - true to print the full text report to the console
%
% Outputs:
%   report - struct:
%          .accounting - per-leg/total gates vs delivered vs dropped
%          .dropClassification - per-drop-row leg/ardStep/dtStimMs/kind
%          .onTarget - per-delivered-pulse abs(dtStimMs - estSSms/2) and
%                 summary stats (device-only; no C3D required)
%          .loopTiming - loopSegMs percentiles and gateLeadMs* extrema
%          .firmwareFingerprint - per-leg gate-to-drop-echo latency
%                 against the pre-/post-2026-09-14 expiry bounds, to
%                 confirm which firmware build actually produced this
%                 datlog without needing lab access to the Arduino
%          .groundTruth - [] if options.C3DPath was not given, else a
%                 struct with per-leg stride-count deficit, true double
%                 support, estSS bias, toe-off reference error, true
%                 placement (%SS), and a corrected stim-to-stride
%                 mapping (ardStep/trueStrideIdx/pctSS per delivered
%                 pulse) for re-deriving an intensity schedule from
%                 actual stride index rather than an assumed one
%
% Toolbox Dependencies: BTK (btkReadAcquisition, btkGetAnalogs,
%          btkGetAnalogFrequency, btkDeleteAcquisition) if
%          options.C3DPath is given; none otherwise.
%
% See also NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO, PARSESTIMECHO,
% UTILS.BUILDDATLOGFRAMETABLE.

arguments
    datlogPath (1,:) char
    options.C3DPath (1,:) char = ''
    options.StimTriggerChannelL (1,:) char = ...
        'Stimulator_Trigger_Sync_Left__Stimulator'
    options.StimTriggerChannelR (1,:) char = ...
        'Stimulator_Trigger_Sync_Right_Stimulator'
    options.ForcePlateChannel1 (1,:) char = 'Force_Fz1'
    options.ForcePlateChannel2 (1,:) char = 'Force_Fz2'
    options.StimTriggerThresholdV (1,1) double {mustBePositive} = 2
    options.ForceThresholdN (1,1) double {mustBePositive} = 100
    options.Verbose (1,1) logical = true
end

%% Load Datlog
loaded = load(datlogPath);
if isfield(loaded,'datlog')
    datlog = loaded.datlog;
elseif isfield(loaded,'stim')
    datlog = loaded; % already-unwrapped struct was passed in via a
    % re-saved variable rather than the controller's own save() call
else
    error('auditHreflexStimTiming:MissingDatlog', ...
        ['%s does not contain a top-level ''datlog'' struct (or an ' ...
        'already-unwrapped struct with a ''stim'' field).'],datlogPath);
end

% A trial with zero delivered pulses (e.g., the Arduino never responding
% -- see the 2026-09-16 incident in studies/SpinalAdapt/README.md) leaves
% deviceEcho.data 0x0 from the controller's own initializer, which fails
% column indexing below (e.g., echo(:,7)) the same way an absent
% deviceDrop already did before that field existed; both are normalized
% to the shared 10-column schema once here rather than at each call site.
if ~isfield(datlog.stim,'deviceEcho') || isempty(datlog.stim.deviceEcho.data)
    datlog.stim.deviceEcho.data = zeros(0,10);
end
if ~isfield(datlog.stim,'deviceDrop') || isempty(datlog.stim.deviceDrop.data)
    datlog.stim.deviceDrop.data = zeros(0,10);
end

report = struct();
report.datlogPath  = datlogPath;
report.accounting  = checkAccounting(datlog);
report.dropClassification = classifyDrops(datlog);
report.onTarget    = checkOnTarget(datlog);
report.loopTiming  = checkLoopTiming(datlog);
report.firmwareFingerprint = checkFirmwareFingerprint(datlog);

%% Ground-Truth Checks (Optional, Requires C3D)
if isempty(options.C3DPath)
    report.groundTruth = [];
else
    if exist('btkReadAcquisition','file') ~= 3 ...
            && exist('btkReadAcquisition','file') ~= 2
        error('auditHreflexStimTiming:MissingBTK', ...
            ['btkReadAcquisition is not on the MATLAB path; add BTK ' ...
            '(e.g., addpath(''Z:\\Nathan\\btk'')) before passing ' ...
            'options.C3DPath.']);
    end
    report.groundTruth = checkGroundTruth(datlog,options);
end

%% Print Report
if options.Verbose
    printReport(report);
end

end

%% Local Functions

function accounting = checkAccounting(datlog)
%CHECKACCOUNTING Per-leg gates-sent vs delivered vs dropped bookkeeping.
%
%   Implements studies/SpinalAdapt/README.md acceptance check 2: every
%   gate MATLAB sent should resolve to exactly one delivered pulse or one
%   dropped-gate echo. datlog.stim.deviceDrop may be absent entirely on a
%   datlog collected before the 2026-08-06 fix (see that README); this
%   is treated as zero drops rather than an error.
%
% Inputs:
%   datlog - struct with stim.L, stim.R, stim.deviceEcho.data, and
%          optionally stim.deviceDrop.data
%
% Outputs:
%   accounting - struct with fields L, R, total, each holding nGates,
%          nDelivered, nDropped, nUnaccounted (nGates - nDelivered -
%          nDropped; nonzero flags a gate whose outcome was never
%          echoed, e.g. a trial stopped mid-stance on old firmware)
%
% Toolbox Dependencies: None
%
% See also AUDITHREFLEXSTIMTIMING, CLASSIFYDROPS.

echo = datlog.stim.deviceEcho.data;
if isfield(datlog.stim,'deviceDrop') && ~isempty(datlog.stim.deviceDrop.data)
    drop = datlog.stim.deviceDrop.data;
else
    drop = zeros(0,10);
end

accounting.L = legAccounting(datlog.stim.L,echo,drop,1);
accounting.R = legAccounting(datlog.stim.R,echo,drop,2);
accounting.total.nGates       = accounting.L.nGates + accounting.R.nGates;
accounting.total.nDelivered   = accounting.L.nDelivered + accounting.R.nDelivered;
accounting.total.nDropped     = accounting.L.nDropped + accounting.R.nDropped;
accounting.total.nUnaccounted = accounting.L.nUnaccounted + accounting.R.nUnaccounted;

end

function legOut = legAccounting(gateRows,echo,drop,legNum)
%LEGACCOUNTING One leg's slice of CHECKACCOUNTING's bookkeeping.
%
% Inputs:
%   gateRows - Nx3 datlog.stim.L or .R array
%   echo     - Mx10 datlog.stim.deviceEcho.data (both legs)
%   drop     - Px10 datlog.stim.deviceDrop.data (both legs)
%   legNum   - 1 (left) or 2 (right); matches echo/drop column 1
%
% Outputs:
%   legOut - struct with nGates, nDelivered, nDropped, nUnaccounted
%
% Toolbox Dependencies: None
%
% See also CHECKACCOUNTING.

legOut.nGates       = size(gateRows,1);
legOut.nDelivered   = sum(echo(:,1) == legNum);
legOut.nDropped     = sum(drop(:,1) == legNum);
legOut.nUnaccounted = legOut.nGates - legOut.nDelivered - legOut.nDropped;

end

function dropTable = classifyDrops(datlog)
%CLASSIFYDROPS Split dropped gates into lateness vs gate-expiry.
%
%   A drop is classified against the two guards in the firmware's
%   triggerStimulation(): the lateness guard drops a gate once dtStimMs
%   exceeds ~(percentSS2Stim + pctSSLateTolerance)*estSSms (0.55*estSS by
%   default), and the gate-expiry guard drops a gate whose single-stance
%   onset never arrived. The expiry bound differs by firmware version
%   (durGateMaxAgeFactor*estSSms post-2026-09, a fixed 2000 ms before
%   it), so the boundary used here (min(1.5*estSSms, 1900)) is
%   conservative for either: 1.5*estSSms never exceeds 1500 ms given the
%   1000 ms EWMA outlier clamp, well under the old fixed 2000 ms bound.
%
% Inputs:
%   datlog - struct, optionally with stim.deviceDrop.data
%
% Outputs:
%   dropTable - Kx1 struct array (one row per dropped gate), each with
%          leg (1/2), ardStep, dtStimMs, estSSms, kind ('lateness',
%          'expiry', or 'unclear')
%
% Toolbox Dependencies: None
%
% See also AUDITHREFLEXSTIMTIMING, CHECKACCOUNTING.

pctSS2Stim        = 0.50; % matches firmware percentSS2Stim
pctSSLateTol      = 0.05; % matches firmware pctSSLateTolerance
expiryFactor      = 1.5;  % matches firmware durGateMaxAgeFactor
expiryFallbackMs  = 1900; % ms; conservative vs. pre-2026-09 fixed 2000 ms

dropTable = struct('leg',{},'ardStep',{},'dtStimMs',{},'estSSms',{}, ...
    'kind',{});
if ~isfield(datlog.stim,'deviceDrop') || isempty(datlog.stim.deviceDrop.data)
    return;
end

drop = datlog.stim.deviceDrop.data;
for rr = 1:size(drop,1)
    estSSms   = drop(rr,6);
    dtStimMs  = drop(rr,7);
    lateBound = (pctSS2Stim + pctSSLateTol) * estSSms;
    expBound  = min(expiryFactor * estSSms,expiryFallbackMs);
    if dtStimMs > expBound
        kind = 'expiry';
    elseif dtStimMs > lateBound
        kind = 'lateness';
    else
        kind = 'unclear';
    end
    dropTable(end+1) = struct('leg',drop(rr,1),'ardStep',drop(rr,2), ...
        'dtStimMs',dtStimMs,'estSSms',estSSms,'kind',kind); %#ok<AGROW>
end

end

function onTarget = checkOnTarget(datlog)
%CHECKONTARGET Device-only on-target metric for every delivered pulse.
%
%   Computes studies/SpinalAdapt/README.md acceptance check 5's own
%   metric, abs(dtStimMs - estSSms/2), for every delivered pulse. Unlike
%   the stored pctSS column (which divides by durSSms, a MATLAB-measured
%   value one stride stale -- see the pctSSLive comment in
%   NirsHreflexArduinoOpenLoopWithAudio.m), this uses only Arduino-side,
%   same-stride values, so it needs no C3D and carries no denominator
%   lag.
%
% Inputs:
%   datlog - struct with stim.deviceEcho.data
%
% Outputs:
%   onTarget - struct: errMs (Nx1 abs error per delivered pulse, ms),
%          meanMs, medianMs, maxMs, nOutsideTolerance (errMs > 5 ms, the
%          README's own acceptance bound)
%
% Toolbox Dependencies: None
%
% See also AUDITHREFLEXSTIMTIMING.

toleranceMs = 5; % ms; README acceptance check 5

echo = datlog.stim.deviceEcho.data;
dtStimMs = echo(:,7);
estSSms  = echo(:,6);
errMs    = abs(dtStimMs - estSSms / 2);

onTarget.errMs   = errMs;
onTarget.meanMs  = mean(errMs,'omitnan');
onTarget.medianMs = median(errMs,'omitnan');
if isempty(errMs)
    onTarget.maxMs = NaN; % max([]) returns [] rather than NaN; a zero-
    % delivery trial must still print cleanly (mean/median already give
    % NaN for an empty input, so this keeps the three fields consistent)
else
    onTarget.maxMs = max(errMs,[],'omitnan');
end
onTarget.nOutsideTolerance = sum(errMs > toleranceMs);

end

function loopTiming = checkLoopTiming(datlog)
%CHECKLOOPTIMING Loop-iteration timing and gate-lead-time summary.
%
%   Implements studies/SpinalAdapt/README.md acceptance checks 6-7:
%   diagnostics.loopSegMs should stay near the documented baseline
%   (median ~10-11 ms, p95 ~70-90 ms) and diagnostics.gateLeadMs* should
%   stay positive (a gate that arrives at or after single-stance onset,
%   rather than during the preceding double support, has lost its safety
%   margin).
%
% Inputs:
%   datlog - struct with diagnostics.loopSegMs, .gateLeadMsL, .gateLeadMsR
%
% Outputs:
%   loopTiming - struct: iterTotalMedianMs, iterTotalP95Ms,
%          iterTotalMaxMs, gateLeadMinMs, gateLeadMeanMs,
%          nGateLeadBelow30Ms (an arbitrarily-chosen low-margin flag, 30
%          ms, well under a normal double-support duration)
%
% Toolbox Dependencies: None
%
% See also AUDITHREFLEXSTIMTIMING.

lowMarginMs = 30; % ms; flag threshold for a gate lead with little margin

iterTotalMs = datlog.diagnostics.loopSegMs(:,1);
gateLeadMs  = [datlog.diagnostics.gateLeadMsL(:); ...
    datlog.diagnostics.gateLeadMsR(:)];

loopTiming.iterTotalMedianMs = median(iterTotalMs,'omitnan');
loopTiming.iterTotalP95Ms    = prctile(iterTotalMs,95);
loopTiming.iterTotalMaxMs    = max(iterTotalMs,[],'omitnan');
if isempty(gateLeadMs) % min([]) returns [] rather than NaN (see the
    % matching onTarget.maxMs guard above); a zero-gate trial must still
    % print cleanly
    loopTiming.gateLeadMinMs = NaN;
else
    loopTiming.gateLeadMinMs = min(gateLeadMs,[],'omitnan');
end
loopTiming.gateLeadMeanMs    = mean(gateLeadMs,'omitnan');
loopTiming.nGateLeadBelow30Ms = sum(gateLeadMs < lowMarginMs);

end

function fingerprint = checkFirmwareFingerprint(datlog)
%CHECKFIRMWAREFINGERPRINT Infer which firmware build produced this datlog.
%
%   Distinguishes pre-2026-09-14 firmware (fixed 2000 ms gate-expiry
%   bound) from the current firmware (durGateMaxAgeFactor * estSS, ~500-
%   750 ms at typical single-stance durations) using only MATLAB-side
%   timestamps already in the datlog -- no C3D or lab access to the
%   Arduino needed. Per leg, deliveries and drops are merged and sorted
%   into one chronological resolution sequence and matched positionally
%   against that leg's gates (stim.L/R column 3, GateSendTime): gates
%   resolve in the order sent, and CHECKACCOUNTING's nUnaccounted == 0 on
%   a clean trial confirms this 1:1 pairing holds. Merging both kinds
%   before matching (rather than matching drops alone against gates) is
%   required whenever drops are a sparse subset of a mostly-successful
%   trial -- otherwise the Nth drop lines up against the Nth GATE rather
%   than the gate it actually resolves, which is wrong as soon as any
%   earlier gate in that leg's sequence was delivered instead of dropped.
%   Only the drop-derived latencies (deviceDrop.data column 10,
%   matTimeSerial) are used for the fingerprint bands below -- a
%   delivered pulse's latency reflects on-target ~50%-single-stance
%   timing, a third band that is not diagnostic of firmware version. A
%   trial with no drops on either leg cannot be fingerprinted this way
%   and is reported inconclusive.
%
%   This is the direct generalization of the ad hoc check that diagnosed
%   the 2026-09-16 pilot (see studies/SpinalAdapt/README.md): every
%   dropped gate on both legs resolved at ~2000 ms, the old fixed bound,
%   proving the 2026-09-14 per-leg-debounce fix had been committed to the
%   repository but never re-flashed onto the physical Arduino.
%
% Inputs:
%   datlog - struct with stim.L, stim.R, and stim.deviceDrop.data
%          (already normalized to zeros(0,10) if empty by the caller)
%
% Outputs:
%   fingerprint - struct: verdict (plain-language firmware guess),
%          latencyMedianMsL/R, nInOldBandL/R (1800-2200 ms), nInNewBandL/R
%          (400-800 ms)
%
% Toolbox Dependencies: None
%
% See also AUDITHREFLEXSTIMTIMING, CHECKACCOUNTING.

oldBandMs = [1800 2200]; % ms; old firmware's fixed 2000 ms durGateMaxAge
newBandMs = [400 800];   % ms; current firmware's ~1.5*estSS band at
                          % typical (not pathologically stalled) estSS

drop = datlog.stim.deviceDrop.data;
echo = datlog.stim.deviceEcho.data;
gateByLeg = {datlog.stim.L, datlog.stim.R};
legLabel  = {'L','R'};

fingerprint = struct();
nOldTotal = 0;
nNewTotal = 0;
for legNum = 1:2
    % tag each resolution isDrop=1/0 before merging so the drop-derived
    % latencies can be recovered after the merged, chronologically
    % matched sequence is built (see the isDrop-merge note above)
    dropLeg = drop(drop(:,1) == legNum,:);
    echoLeg = echo(echo(:,1) == legNum,:);
    dropLeg = [dropLeg,  ones(size(dropLeg,1),1)]; %#ok<AGROW>
    echoLeg = [echoLeg, zeros(size(echoLeg,1),1)]; %#ok<AGROW>
    allResolved = sortrows([dropLeg; echoLeg],10);

    gateRows = gateByLeg{legNum};
    nMatch   = min(size(gateRows,1),size(allResolved,1));
    if nMatch == 0
        latencyMs = [];
    else
        latencyMsAll = (allResolved(1:nMatch,10) - gateRows(1:nMatch,3)) ...
            * 86400 * 1000;
        latencyMs = latencyMsAll(allResolved(1:nMatch,11) == 1);
    end
    nOldBand = sum(latencyMs >= oldBandMs(1) & latencyMs <= oldBandMs(2));
    nNewBand = sum(latencyMs >= newBandMs(1) & latencyMs <= newBandMs(2));

    fingerprint.(['latencyMedianMs' legLabel{legNum}]) = ...
        median(latencyMs,'omitnan');
    fingerprint.(['nInOldBand' legLabel{legNum}]) = nOldBand;
    fingerprint.(['nInNewBand' legLabel{legNum}]) = nNewBand;
    nOldTotal = nOldTotal + nOldBand;
    nNewTotal = nNewTotal + nNewBand;
end

if nOldTotal == 0 && nNewTotal == 0
    fingerprint.verdict = 'inconclusive (no drops in either timing band)';
elseif nOldTotal > 0 && nNewTotal == 0
    fingerprint.verdict = 'likely PRE-2026-09-14 firmware (fixed 2000 ms expiry) -- re-flash needed';
elseif nNewTotal > 0 && nOldTotal == 0
    fingerprint.verdict = 'likely current firmware (scaled 1.5*estSS expiry)';
else
    fingerprint.verdict = 'inconclusive (mixed old- and new-band latencies)';
end

end

function groundTruth = checkGroundTruth(datlog,options)
%CHECKGROUNDTRUTH C3D-referenced ground-truth timing and deficit checks.
%
%   Reads the C3D's stimulator trigger sync channels (exact stim pulse
%   times) and treadmill force-plate channels (true gait events), then
%   for each leg: auto-detects which force plate belongs to that leg,
%   maps every delivered pulse onto the true single-stance stride it
%   landed in, and compares the Arduino's own stride count (ardStep)
%   against how many true strides actually elapsed between consecutive
%   delivered pulses.
%
% Inputs:
%   datlog  - struct with stim.L, stim.R, stim.deviceEcho.data
%   options - the parent function's options struct (C3DPath and the
%          channel-name / threshold options)
%
% Outputs:
%   groundTruth - struct:
%          .legL, .legR - per-leg struct (see MATCHLEGGROUNDTRUTH)
%          .doubleSupportMs - struct: meanMs, sdMs, minMs, nBelowDebounce
%                 (< 100 ms, the firmware's timeDebounce)
%          .estSSBiasMs - mean(Arduino estSSms) - mean(true single
%                 stance), pooled across both legs
%
% Toolbox Dependencies: BTK (btkReadAcquisition, btkGetAnalogs,
%          btkGetAnalogFrequency, btkDeleteAcquisition)
%
% See also AUDITHREFLEXSTIMTIMING, MATCHLEGGROUNDTRUTH.

debounceMs = 100; % ms; firmware timeDebounce

acq = btkReadAcquisition(options.C3DPath);
analog = btkGetAnalogs(acq);
fsHz   = btkGetAnalogFrequency(acq);
btkDeleteAcquisition(acq);

fz1 = -getAnalogChannel(analog,options.ForcePlateChannel1); % N, positive-up
fz2 = -getAnalogChannel(analog,options.ForcePlateChannel2);
trigL = getAnalogChannel(analog,options.StimTriggerChannelL);
trigR = getAnalogChannel(analog,options.StimTriggerChannelR);

pulseL = detectRisingEdges(trigL,options.StimTriggerThresholdV,fsHz,0.05);
pulseR = detectRisingEdges(trigR,options.StimTriggerThresholdV,fsHz,0.05);

% restrict gait-event extraction to the walking bout (padded 3 s around
% the first/last stim pulse) so pre/post-trial standing does not corrupt
% the double-support and single-stance interval statistics
nSamp  = numel(fz1);
tSec   = (0:(nSamp - 1))' / fsHz;
tStart = min(tSec(pulseL(1)),tSec(pulseR(1))) - 3;
tEnd   = max(tSec(pulseL(end)),tSec(pulseR(end))) + 3;
inBout = tSec >= tStart & tSec <= tEnd;

load1 = (fz1 > options.ForceThresholdN) & inBout;
load2 = (fz2 > options.ForceThresholdN) & inBout;

doubleSupportSamples = extractIntervals(load1 & load2,fsHz,0.02);
doubleSupportMs = diff(doubleSupportSamples,1,2) / fsHz * 1000;
doubleSupportMs = doubleSupportMs(doubleSupportMs < 400); % drop any
% interval spanning a full stride (a genuine gait-event miss upstream of
% this tool, not a double-support period)

groundTruth.doubleSupportMs.meanMs = mean(doubleSupportMs,'omitnan');
groundTruth.doubleSupportMs.sdMs   = std(doubleSupportMs,'omitnan');
groundTruth.doubleSupportMs.minMs  = min(doubleSupportMs,[],'omitnan');
groundTruth.doubleSupportMs.nBelowDebounce = ...
    sum(doubleSupportMs < debounceMs);

% single stance under each plate-assignment hypothesis; leg identity is
% resolved per leg by MATCHLEGGROUNDTRUTH below (whichever assignment
% contains that leg's pulses)
ss1 = extractIntervals(load1 & ~load2,fsHz,0.15);
ss2 = extractIntervals(load2 & ~load1,fsHz,0.15);

echo = datlog.stim.deviceEcho.data;
groundTruth.legL = matchLegGroundTruth(echo,1,pulseL,ss1,ss2,fsHz);
groundTruth.legR = matchLegGroundTruth(echo,2,pulseR,ss1,ss2,fsHz);

trueSSAll = [groundTruth.legL.trueSSDurMs; groundTruth.legR.trueSSDurMs];
estSSAll  = [echo(echo(:,1) == 1,6); echo(echo(:,1) == 2,6)];
groundTruth.estSSBiasMs = mean(estSSAll,'omitnan') - mean(trueSSAll,'omitnan');

end

function chan = getAnalogChannel(analog,chanName)
%GETANALOGCHANNEL Fetch one named field from a BTK analog struct.
%
%   Gives a clear, actionable error naming the available channels rather
%   than MATLAB's generic "no such field" message, since a channel-name
%   mismatch (different Nexus configuration, different number of force
%   plates) is the expected failure mode when running this tool on a
%   session it was not validated against.
%
% Inputs:
%   analog   - struct returned by btkGetAnalogs, one field per channel
%   chanName - field name to fetch
%
% Outputs:
%   chan - the channel's Nx1 data vector
%
% Toolbox Dependencies: None
%
% See also CHECKGROUNDTRUTH.

if ~isfield(analog,chanName)
    error('auditHreflexStimTiming:MissingChannel', ...
        ['C3D analog channel ''%s'' not found. Available channels: ' ...
        '%s'],chanName,strjoin(fieldnames(analog)','; '));
end
chan = analog.(chanName);

end

function idx = detectRisingEdges(sig,thresholdV,fsHz,refractorySec)
%DETECTRISINGEDGES Rising-edge sample indices, with a refractory period.
%
% Inputs:
%   sig           - Nx1 analog signal (V)
%   thresholdV    - crossing level (V)
%   fsHz          - sample rate (Hz)
%   refractorySec - minimum spacing between accepted edges (s); collapses
%          a multi-sample crossing into one edge
%
% Outputs:
%   idx - Kx1 sample indices of accepted rising edges
%
% Toolbox Dependencies: None
%
% See also CHECKGROUNDTRUTH.

above = sig(:) > thresholdV;
edges = find(diff([false; above]) == 1);
minGapSamples = round(refractorySec * fsHz);

idx  = zeros(0,1);
last = -inf;
for ee = 1:numel(edges)
    if edges(ee) - last > minGapSamples
        idx(end+1,1) = edges(ee); %#ok<AGROW>
        last = edges(ee);
    end
end

end

function iv = extractIntervals(mask,fsHz,minDurSec)
%EXTRACTINTERVALS Start/end sample indices of each true-run in a mask.
%
% Inputs:
%   mask      - Nx1 logical
%   fsHz      - sample rate (Hz)
%   minDurSec - shortest run to keep (s); shorter runs (sensor noise, a
%          brief double-detect) are dropped
%
% Outputs:
%   iv - Kx2 [startSample endSample], one row per kept run
%
% Toolbox Dependencies: None
%
% See also CHECKGROUNDTRUTH.

mask = mask(:);
startIdx = find(diff([false; mask]) == 1);
endIdx   = find(diff([mask; false]) == -1);
nRuns    = min(numel(startIdx),numel(endIdx));
startIdx = startIdx(1:nRuns);
endIdx   = endIdx(1:nRuns);

keep = (endIdx - startIdx) >= minDurSec * fsHz;
iv   = [startIdx(keep) endIdx(keep)];

end

function legOut = matchLegGroundTruth(echo,legNum,pulses,ss1,ss2,fsHz)
%MATCHLEGGROUNDTRUTH One leg's ground-truth checks against its stim pulses.
%
%   Auto-detects which of the two candidate single-stance interval sets
%   (ss1 from force plate 1, ss2 from force plate 2) belongs to this leg
%   by containment: whichever set holds more of this leg's stim pulses
%   wins. A losing containment below 90% is flagged (lowConfidence) since
%   it signals a channel-identity or gait-detection problem, not merely
%   ordinary timing jitter.
%
%   The Arduino's millis() clock (echo columns stimMs/toRefMs) is
%   regressed onto the C3D's sample clock using the matched delivered
%   pulses themselves (stimMs vs. each pulse's true sample time), then
%   that fit places toRefMs on the C3D timeline to compute
%   toeOffRefErrMs. At least 2 matched pulses are required for the fit;
%   with fewer, toeOffRefErrMs is returned all-NaN.
%
% Inputs:
%   echo   - Mx10 datlog.stim.deviceEcho.data (both legs)
%   legNum - 1 (left) or 2 (right)
%   pulses - Kx1 sample indices of this leg's stimulator trigger pulses
%   ss1, ss2 - Px2 / Qx2 candidate single-stance interval sets (samples),
%          one derived from each force plate
%   fsHz   - C3D analog sample rate (Hz)
%
% Outputs:
%   legOut - struct:
%          .nPulses, .nEchoes - C3D pulse count vs datlog echo count for
%                 this leg (should match; a mismatch means the analog
%                 sync pulse and the serial echo disagree on what fired)
%          .containmentPct, .lowConfidence - which plate assignment won
%                 and whether that win was decisive
%          .pctSS - Kx1 true placement, percent of single stance, per
%                 pulse
%          .trueSSDurMs - Kx1 true single-stance duration (ms) of the
%                 stride each pulse landed in
%          .toeOffRefErrMs - Kx1 (Arduino toRefMs, mapped onto the C3D
%                 clock) minus (true single-stance onset time), ms
%          .strideDeficit, .strideTotal - the Arduino stride-count
%                 deficit (see AUDITHREFLEXSTIMTIMING) and its
%                 denominator (true strides elapsed between the first
%                 and last delivered pulse)
%          .strideMap - Kx3 [ardStep trueStrideIdx pctSS], for
%                 re-deriving a stimulus schedule from true stride index
%
% Toolbox Dependencies: None
%
% See also CHECKGROUNDTRUTH, AUDITHREFLEXSTIMTIMING.

lowConfidenceThresholdPct = 90; % containment %; below this, flag the win
minPulsesForClockFit      = 2;  % polyfit needs >= 2 points

[containPct1,pct1] = containment(pulses,ss1);
[containPct2,pct2] = containment(pulses,ss2);
if containPct1 >= containPct2
    ssThisLeg = ss1;
    pctSS     = pct1;
    legOut.containmentPct = containPct1;
else
    ssThisLeg = ss2;
    pctSS     = pct2;
    legOut.containmentPct = containPct2;
end
legOut.lowConfidence = legOut.containmentPct < lowConfidenceThresholdPct;

echoLeg  = echo(echo(:,1) == legNum,:);
legOut.nPulses = numel(pulses);
legOut.nEchoes = size(echoLeg,1);

nMatch = min(numel(pulses),size(echoLeg,1));
pulses = pulses(1:nMatch);
strideIdx = nan(nMatch,1);
for pp = 1:nMatch
    rr = find(ssThisLeg(:,1) <= pulses(pp) & ssThisLeg(:,2) >= pulses(pp),1);
    if ~isempty(rr)
        strideIdx(pp) = rr;
    end
end

legOut.pctSS = pctSS(1:nMatch);
legOut.trueSSDurMs = nan(nMatch,1);
valid = ~isnan(strideIdx);
legOut.trueSSDurMs(valid) = ...
    diff(ssThisLeg(strideIdx(valid),:),1,2) / fsHz * 1000;

ardSteps = echoLeg(1:nMatch,2);
[legOut.strideDeficit,legOut.strideTotal] = ...
    strideCountDeficit(ardSteps,strideIdx);

legOut.strideMap = [ardSteps strideIdx legOut.pctSS];

legOut.toeOffRefErrMs = nan(nMatch,1);
if sum(valid) >= minPulsesForClockFit
    ardStimMsSec = echoLeg(1:nMatch,4) / 1000; % stimMs -> Arduino seconds
    pulseTimeSec = pulses / fsHz;              % same pulses, C3D seconds
    clockFit = polyfit(ardStimMsSec(valid),pulseTimeSec(valid),1);
    toRefTimeSec = polyval(clockFit,echoLeg(1:nMatch,5) / 1000);
    onsetTimeSec = nan(nMatch,1);
    onsetTimeSec(valid) = ssThisLeg(strideIdx(valid),1) / fsHz;
    legOut.toeOffRefErrMs = (toRefTimeSec - onsetTimeSec) * 1000;
end

end

function [pct,pctSS] = containment(pulses,intervals)
%CONTAINMENT Fraction of pulses landing inside a candidate interval set.
%
% Inputs:
%   pulses    - Kx1 sample indices
%   intervals - Px2 [startSample endSample]
%
% Outputs:
%   pct   - scalar; percent of pulses inside some interval
%   pctSS - Kx1 percent-of-interval placement (NaN where not contained)
%
% Toolbox Dependencies: None
%
% See also MATCHLEGGROUNDTRUTH.

pctSS = nan(numel(pulses),1);
for pp = 1:numel(pulses)
    rr = find(intervals(:,1) <= pulses(pp) & intervals(:,2) >= pulses(pp),1);
    if ~isempty(rr)
        pctSS(pp) = 100 * (pulses(pp) - intervals(rr,1)) / ...
            (intervals(rr,2) - intervals(rr,1));
    end
end
pct = 100 * sum(~isnan(pctSS)) / numel(pctSS);

end

function [deficit,totalStrides] = strideCountDeficit(ardSteps,strideIdx)
%STRIDECOUNTDEFICIT Strides the Arduino failed to count between pulses.
%
%   For each pair of consecutive delivered pulses, the number of true
%   strides that elapsed (diff(strideIdx)) should equal the Arduino's own
%   stride count increment (diff(ardSteps)). A positive difference is a
%   stride the firmware's gait-event state machine silently missed (see
%   the module doc comment).
%
% Inputs:
%   ardSteps  - Nx1 Arduino ardStep at each delivered pulse, in order
%   strideIdx - Nx1 true stride index at each delivered pulse, in order
%          (NaN where a pulse could not be matched to a true stride)
%
% Outputs:
%   deficit      - total strides missed (sum of positive deficits only)
%   totalStrides - total true strides elapsed between consecutive
%          matched pulses (the deficit's denominator)
%
% Toolbox Dependencies: None
%
% See also MATCHLEGGROUNDTRUTH.

valid = ~isnan(strideIdx);
ardSteps  = ardSteps(valid);
strideIdx = strideIdx(valid);

dTrue = diff(strideIdx);
dArd  = diff(ardSteps);
perGapDeficit = dTrue - dArd;

deficit      = sum(perGapDeficit(perGapDeficit > 0));
totalStrides = sum(dTrue);

end

function printReport(report)
%PRINTREPORT Print AUDITHREFLEXSTIMTIMING's report struct to the console.
%
% Inputs:
%   report - struct produced by AUDITHREFLEXSTIMTIMING
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also AUDITHREFLEXSTIMTIMING.

fprintf('\n===== H-Reflex Stim Timing Audit: %s =====\n', ...
    report.datlogPath);

fprintf('\n-- Accounting --\n');
printLegAccounting('L',report.accounting.L);
printLegAccounting('R',report.accounting.R);
tot = report.accounting.total;
fprintf(['TOTAL: %d gates, %d delivered, %d dropped, %d ' ...
    'unaccounted\n'],tot.nGates,tot.nDelivered,tot.nDropped, ...
    tot.nUnaccounted);

if ~isempty(report.dropClassification)
    fprintf('\n-- Drop Classification (%d drops) --\n', ...
        numel(report.dropClassification));
    for dd = 1:numel(report.dropClassification)
        rowD = report.dropClassification(dd);
        fprintf('  leg %d ardStep %d: dtStim=%.0f ms -> %s\n', ...
            rowD.leg,rowD.ardStep,rowD.dtStimMs,rowD.kind);
    end
else
    fprintf('\n-- Drop Classification: none (clean) --\n');
end

fprintf('\n-- On-Target Metric |dtStimMs - estSSms/2| --\n');
ot = report.onTarget;
fprintf(['mean=%.1f ms median=%.1f ms max=%.1f ms | outside +/-5 ' ...
    'ms: %d\n'],ot.meanMs,ot.medianMs,ot.maxMs,ot.nOutsideTolerance);

fprintf('\n-- Loop Timing --\n');
lt = report.loopTiming;
fprintf('iterTotalMs: median=%.2f p95=%.1f max=%.1f\n', ...
    lt.iterTotalMedianMs,lt.iterTotalP95Ms,lt.iterTotalMaxMs);
fprintf('gateLeadMs: mean=%.1f min=%.1f | below 30 ms: %d\n', ...
    lt.gateLeadMeanMs,lt.gateLeadMinMs,lt.nGateLeadBelow30Ms);

fprintf('\n-- Firmware Fingerprint (gate-to-drop-echo latency) --\n');
fp = report.firmwareFingerprint;
fprintf('%s\n',fp.verdict);
fprintf('L: median=%.0f ms | old-band(~2000ms)=%d new-band(~595ms)=%d\n', ...
    fp.latencyMedianMsL,fp.nInOldBandL,fp.nInNewBandL);
fprintf('R: median=%.0f ms | old-band(~2000ms)=%d new-band(~595ms)=%d\n', ...
    fp.latencyMedianMsR,fp.nInOldBandR,fp.nInNewBandR);

if isempty(report.groundTruth)
    fprintf('\n-- Ground Truth: skipped (no C3D path given) --\n');
    return;
end

gt = report.groundTruth;
fprintf('\n-- Ground Truth (C3D) --\n');
fprintf('double support: mean=%.1f ms sd=%.1f min=%.1f | <100ms: %d\n', ...
    gt.doubleSupportMs.meanMs,gt.doubleSupportMs.sdMs, ...
    gt.doubleSupportMs.minMs,gt.doubleSupportMs.nBelowDebounce);
fprintf('estSS bias (Arduino - true): %+.1f ms\n',gt.estSSBiasMs);
printLegGroundTruth('L',gt.legL);
printLegGroundTruth('R',gt.legR);

end

function printLegAccounting(legLabel,legOut)
%PRINTLEGACCOUNTING One leg's accounting line for PRINTREPORT.
%
% Inputs:
%   legLabel - 'L' or 'R'
%   legOut   - struct from CHECKACCOUNTING/LEGACCOUNTING
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also PRINTREPORT.

fprintf('%s: %d gates, %d delivered, %d dropped, %d unaccounted\n', ...
    legLabel,legOut.nGates,legOut.nDelivered,legOut.nDropped, ...
    legOut.nUnaccounted);

end

function printLegGroundTruth(legLabel,legOut)
%PRINTLEGGROUNDTRUTH One leg's ground-truth block for PRINTREPORT.
%
% Inputs:
%   legLabel - 'L' or 'R'
%   legOut   - struct from MATCHLEGGROUNDTRUTH
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also PRINTREPORT.

confidenceStr = 'ok';
if legOut.lowConfidence
    confidenceStr = 'LOW CONFIDENCE, check channel names';
end
fprintf(['%s: %d C3D pulses, %d echoes, plate containment=%.1f%% ' ...
    '(%s)\n'],legLabel,legOut.nPulses,legOut.nEchoes, ...
    legOut.containmentPct,confidenceStr);
fprintf('%s: true placement %%SS mean=%.1f sd=%.1f range %.1f-%.1f\n', ...
    legLabel,mean(legOut.pctSS,'omitnan'),std(legOut.pctSS,'omitnan'), ...
    min(legOut.pctSS,[],'omitnan'),max(legOut.pctSS,[],'omitnan'));
fprintf('%s: Arduino stride-count deficit: %d of %d true strides\n', ...
    legLabel,legOut.strideDeficit,legOut.strideTotal);
fprintf('%s: toe-off reference error: mean=%+.1f ms max|.|=%.1f ms\n', ...
    legLabel,mean(legOut.toeOffRefErrMs,'omitnan'), ...
    max(abs(legOut.toeOffRefErrMs),[],'omitnan'));

end
