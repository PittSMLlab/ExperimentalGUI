function frameTable = buildDatlogFrameTable(datlog)
%BUILDDATLOGFRAMETABLE Consolidate per-frame datlog arrays into one table.
%
%   Joins the datlog's separately-logged per-frame arrays (forces,
%   Bertec-reported and commanded belt speeds, gait events, H-reflex
%   stim gate sends) onto one Vicon-frame-indexed timetable, so
%   downstream analysis can read treadmill behavior and gait/stim events
% alongside force data without re-deriving the joins by hand. This is a
% read-side VIEW: nothing here is written back into datlog or saved to
% disk, so it adds no new fields to the saved .mat file and no memory
% cost to tools (e.g., labTools) that load many datlogs at once.
%
%   Every source beyond the required forces.data master is optional and
% defaults to NaN/false if absent, so this also runs on already-
% collected (legacy) datlogs that predate newer fields (e.g., stim,
% TreadmillCommands.sent) -- no converter is needed for those logs.
%
%   The device stim echo (datlog.stim.deviceEcho) and loop-timing
% diagnostics (datlog.diagnostics) are intentionally excluded: the echo
% is timestamped on the Arduino's own millis() clock, which is not
% directly alignable with this table's Vicon-frame uTime axis (see
% NirsHreflexArduinoOpenLoopWithAudio's stim.deviceEcho comment), and
% diagnostics describe loop behavior, not the trial.
%
% Inputs:
%   datlog - struct as consumed by SYNCDATALOG (already unwrapped from
%          the load()-created datlog.datlog nesting; see
%          trialMetaData.m), produced by a controller in the
%          NirsHreflexArduinoOpenLoopWithAudio family. Must contain
%          forces.data; TreadmillCommands.read/.sent, stepdata.*, and
%          stim.L/.R are read if present and skipped otherwise.
%
% Outputs:
%   frameTable - timetable, one row per Vicon frame (row times = uTime
%          converted to datetime), with variables:
%            frameNum         - Vicon frame number
%            uTime            - raw datlog serial-date timestamp
%            relTime          - seconds since the first logged frame
%            Rfz, Lfz         - right/left force-plate vertical force
%                                (N)
%            beltSpeedRRead,
%            beltSpeedLRead   - Bertec-reported belt speed (mm/s)
%            inclineRead      - Bertec-reported incline angle
%            beltSpeedRCmd,
%            beltSpeedLCmd    - last commanded belt speed (mm/s)
%            isRHS, isLHS,
%            isRTO, isLTO     - true on the frame a gait event fired
%                                (cumsum(isRHS), etc., recovers the step
%                                number if needed)
%            stimGateL,
%            stimGateR        - true on the frame nearest an H-reflex
%                                stim gate send
%            stimDelayTargetL,
%            stimDelayTargetR - diagnostic target stim delay (ms) on
%                                stimGateL/R frames, NaN elsewhere
%
% Toolbox Dependencies: None
%
% See also NIRSHREFLEXARDUINOOPENLOOPWITHAUDIO, SYNCDATALOG,
% TESTBUILDDATLOGFRAMETABLE.

arguments
    datlog (1,1) struct
end

if ~isfield(datlog,'forces') || ~isfield(datlog.forces,'data') ...
        || isempty(datlog.forces.data)
    error('buildDatlogFrameTable:MissingForces', ...
        'datlog.forces.data is required to build the frame table.');
end

%% Master Timeline (Forces)
forceData = datlog.forces.data;
frameNum  = forceData(:,1);
uTime     = forceData(:,2);
Rfz       = forceData(:,3);
Lfz       = forceData(:,4);
relTime   = forceData(:,5);

%% Belt Speeds (Bertec-Reported, Read Path)
if isfield(datlog,'TreadmillCommands') ...
        && isfield(datlog.TreadmillCommands,'read') ...
        && ~isempty(datlog.TreadmillCommands.read)
    readData     = datlog.TreadmillCommands.read;
    beltReadVals = sampleAtNearestTime(uTime,readData(:,4), ...
        readData(:,1:3));
else
    beltReadVals = nan(numel(uTime),3);
end
beltSpeedRRead = beltReadVals(:,1);
beltSpeedLRead = beltReadVals(:,2);
inclineRead    = beltReadVals(:,3);

%% Belt Speeds (Commanded, Sent Path)
if isfield(datlog,'TreadmillCommands') ...
        && isfield(datlog.TreadmillCommands,'sent') ...
        && ~isempty(datlog.TreadmillCommands.sent)
    sentData = datlog.TreadmillCommands.sent;
    if isfield(datlog.TreadmillCommands,'firstSent') ...
            && ~isempty(datlog.TreadmillCommands.firstSent)
        firstCmd = datlog.TreadmillCommands.firstSent(1,1:2);
    else % no recorded first command; hold the earliest sent value
        firstCmd = sentData(1,1:2);
    end
    beltCmdVals = holdPreviousValue(uTime,sentData(:,4), ...
        sentData(:,1:2),firstCmd);
else
    beltCmdVals = nan(numel(uTime),2);
end
beltSpeedRCmd = beltCmdVals(:,1);
beltSpeedLCmd = beltCmdVals(:,2);

%% Gait Events
isRHS = gaitEventMask(datlog,'RHSdata',frameNum);
isLHS = gaitEventMask(datlog,'LHSdata',frameNum);
isRTO = gaitEventMask(datlog,'RTOdata',frameNum);
isLTO = gaitEventMask(datlog,'LTOdata',frameNum);

%% H-Reflex Stim Gate Sends
[stimGateL,stimDelayTargetL] = stimGateMask(datlog,'L',uTime);
[stimGateR,stimDelayTargetR] = stimGateMask(datlog,'R',uTime);

%% Assemble Frame Table
rowTimes = datetime(uTime,'ConvertFrom','datenum');
frameTable = timetable(rowTimes,frameNum,uTime,relTime,Rfz,Lfz, ...
    beltSpeedRRead,beltSpeedLRead,inclineRead, ...
    beltSpeedRCmd,beltSpeedLCmd, ...
    isRHS,isLHS,isRTO,isLTO, ...
    stimGateL,stimGateR,stimDelayTargetL,stimDelayTargetR);

end

%% Local Functions

function [tOut,valsOut] = collapseRepeatedTimes(tIn,valsIn)
%COLLAPSEREPEATEDTIMES Keep the last row of each run of equal timestamps.
%
%   Interpolation requires strictly increasing sample times; datlog
%   arrays occasionally share a timestamp across consecutive frames when
% two writes land within one system-clock tick. Collapsing to the last
% value of each run matches the arrays' own append-order convention
% (always written chronologically, so "last" is "most recent").
%
% Inputs:
%   tIn    - Nx1 non-decreasing timestamps (datenum)
%   valsIn - NxM values aligned with tIn
%
% Outputs:
%   tOut    - Kx1 strictly increasing timestamps, K <= N
%   valsOut - KxM values, last row of each repeated-time run
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE.

keepRow = [diff(tIn) ~= 0; true];
tOut    = tIn(keepRow);
valsOut = valsIn(keepRow,:);

end

function valsAtQuery = sampleAtNearestTime(tQuery,tSource,valsSource)
%SAMPLEATNEARESTTIME Zero-order-hold join by nearest source timestamp.
%
%   For each query time, returns the source row whose timestamp is
%   closest. Used to align a near-per-frame source array (e.g.,
% TreadmillCommands.read) onto the frame table's master timeline
% without assuming identical row counts.
%
% Inputs:
%   tQuery     - Px1 master timestamps (datenum)
%   tSource    - Nx1 source timestamps (datenum), chronological
%   valsSource - NxM source values aligned with tSource
%
% Outputs:
%   valsAtQuery - PxM values, one row per query time
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, HOLDPREVIOUSVALUE,
% COLLAPSEREPEATEDTIMES.

numCols = size(valsSource,2);
if isempty(tSource)
    valsAtQuery = nan(numel(tQuery),numCols);
    return;
end

[tSource,valsSource] = collapseRepeatedTimes(tSource,valsSource);

if isscalar(tSource) % INTERP1 requires >= 2 points; hold the constant
    valsAtQuery = repmat(valsSource,numel(tQuery),1);
    return;
end

valsAtQuery = interp1(tSource,valsSource,tQuery,'nearest','extrap');

end

function valsAtQuery = holdPreviousValue(tQuery,tSource,valsSource, ...
    beforeFirstVals)
%HOLDPREVIOUSVALUE Causal (zero-order-hold) join onto a query timeline.
%
%   For each query time, returns the most recently known source value
%   at or before that time -- i.e., what was actually in effect, never a
% future value. Used for sparse event logs (e.g.,
% TreadmillCommands.sent, which only has a row when the commanded speed
% changes) so every frame reflects the command actually active then.
%
% Inputs:
%   tQuery          - Px1 master timestamps (datenum)
%   tSource         - Nx1 source event timestamps (datenum),
%          chronological
%   valsSource      - NxM source values aligned with tSource
%   beforeFirstVals - 1xM value to use for query times before the first
%          source event (e.g., the trial's first commanded speed)
%
% Outputs:
%   valsAtQuery - PxM values, one row per query time
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, SAMPLEATNEARESTTIME,
% COLLAPSEREPEATEDTIMES.

if isempty(tSource)
    valsAtQuery = repmat(beforeFirstVals,numel(tQuery),1);
    return;
end

[tSource,valsSource] = collapseRepeatedTimes(tSource,valsSource);

% anchor with the pre-trial value so queries before the first event
% hold it instead of extrapolating the first event's value backward
anchorTime = min([tQuery(1);tSource(1)]) - 1; % 1 day always earlier
tSource    = [anchorTime;tSource];
valsSource = [beforeFirstVals;valsSource];

if isscalar(tSource)
    valsAtQuery = repmat(valsSource,numel(tQuery),1);
    return;
end

valsAtQuery = interp1(tSource,valsSource,tQuery,'previous','extrap');

end

function rowIdx = nearestFrameIndex(tEvent,tMaster)
%NEARESTFRAMEINDEX Map event timestamps onto the closest master frame.
%
%   Used to place sparse, non-per-frame events (H-reflex stim gate
%   sends) onto the frame table: each event lands on exactly one row,
% the frame whose timestamp is closest to the event time.
%
% Inputs:
%   tEvent  - Mx1 event timestamps (datenum)
%   tMaster - Px1 master (frame) timestamps (datenum), chronological
%
% Outputs:
%   rowIdx - Mx1 row indices into tMaster, one per event
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, STIMGATEMASK, COLLAPSEREPEATEDTIMES.

frameIdxAll = (1:numel(tMaster))';
[tMasterDedup,idxDedup] = collapseRepeatedTimes(tMaster,frameIdxAll);

if isscalar(tMasterDedup)
    rowIdx = repmat(idxDedup,numel(tEvent),1);
    return;
end

nearestDedupPos = interp1(tMasterDedup,1:numel(tMasterDedup),tEvent, ...
    'nearest','extrap');
rowIdx = idxDedup(round(nearestDedupPos));

end

function isEvent = frameNumToMasterMask(masterFrameNum,eventFrameNum)
%FRAMENUMTOMASTERMASK Mark master rows whose frame# matches an event.
%
%   Drops non-positive event frame numbers before matching, since a
%   stepdata array's preallocated-but-never-filled rows are zero (see
% NirsHreflexArduinoOpenLoopWithAudio's stepdata init) and would
% otherwise spuriously match frame 0.
%
% Inputs:
%   masterFrameNum - Px1 frame numbers from the master timeline
%   eventFrameNum  - Mx1 frame numbers where an event was detected
%
% Outputs:
%   isEvent - Px1 logical, true on rows matching an event frame#
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, GAITEVENTMASK.

eventFrameNum = eventFrameNum(eventFrameNum > 0);
isEvent = ismember(masterFrameNum,eventFrameNum);

end

function isEvent = gaitEventMask(datlog,fieldName,masterFrameNum)
%GAITEVENTMASK Exact frame-number join for one stepdata event array.
%
%   stepdata.(fieldName) logs the Vicon frame# (column 3) each gait
%   event was detected on, so events are placed on the frame table by
% direct frame# match -- no time-based approximation needed. Returns
% all-false if the field is absent (e.g., a legacy or non-family
% datlog), so callers do not need their own presence checks.
%
% Inputs:
%   datlog         - struct with an optional stepdata.(fieldName) array
%   fieldName      - name of the stepdata event array (e.g., 'RHSdata')
%   masterFrameNum - Px1 frame numbers from the master timeline
%
% Outputs:
%   isEvent - Px1 logical, true on rows matching an event frame#
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, FRAMENUMTOMASTERMASK.

if ~isfield(datlog,'stepdata') || ~isfield(datlog.stepdata,fieldName) ...
        || isempty(datlog.stepdata.(fieldName))
    isEvent = false(size(masterFrameNum));
    return;
end

eventFrameNum = datlog.stepdata.(fieldName)(:,3);
isEvent = frameNumToMasterMask(masterFrameNum,eventFrameNum);

end

function [isGate,delayTarget] = stimGateMask(datlog,side,masterUTime)
%STIMGATEMASK Nearest-frame join for one side's stim gate sends.
%
%   datlog.stim.(side) logs [step#, delayTarget(ms), gateSendTime] with
%   no frame#, so each gate send is placed on the frame table's nearest
% frame by timestamp (see NEARESTFRAMEINDEX). Returns all-false/NaN if
% datlog.stim.(side) is absent or empty (e.g., a non-H-reflex trial or
% a legacy datlog), so callers do not need their own presence checks.
%
% Inputs:
%   datlog      - struct with an optional stim.(side) array
%   side        - 'L' or 'R'
%   masterUTime - Px1 master timestamps (datenum)
%
% Outputs:
%   isGate      - Px1 logical, true on the frame nearest a gate send
%   delayTarget - Px1 diagnostic target stim delay (ms) on isGate
%          frames, NaN elsewhere
%
% Toolbox Dependencies: None
%
% See also BUILDDATLOGFRAMETABLE, NEARESTFRAMEINDEX.

isGate      = false(size(masterUTime));
delayTarget = nan(size(masterUTime));

if ~isfield(datlog,'stim') || ~isfield(datlog.stim,side) ...
        || isempty(datlog.stim.(side))
    return;
end

stimData             = datlog.stim.(side);
rowIdx               = nearestFrameIndex(stimData(:,3),masterUTime);
isGate(rowIdx)       = true;
delayTarget(rowIdx)  = stimData(:,2);

end
