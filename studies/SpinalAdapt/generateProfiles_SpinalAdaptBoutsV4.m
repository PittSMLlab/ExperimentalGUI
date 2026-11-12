function profileDir = generateProfiles_SpinalAdaptBoutsV4( ...
    slowSpeed, fastSpeed, fastestSpeed, profileDir)
%GENERATEPROFILES_SPINALADAPTBOUTSV4 Generate speed and stim profiles for
% Version 4.0 of the SpinalAdapt protocol and save them to disk.
%
%   Version 4.0 (2026-11-09) of GENERATEPROFILES_SPINALADAPTBOUTS. The
%   H-reflex walking calibration, tied fastest-speed, and pre-adaptation
%   fast profiles are unchanged. Every pre-adaptation slow, adaptation
%   split, and post-adaptation slow bout now starts tied-fast instead of
%   ramping straight to its target speeds: a tied ramp from rest to
%   fastSpeed (rampStrides, the last of which is already at fastSpeed),
%   one more tied-fast stride (fastHoldStrides), then an abrupt switch to
%   tied-slow or split walking for ssStrides strides, then the rest pad
%   (stand and count). Stimulation is on every post-switch stride only.
%
%   The changed profiles are saved under new names (PreAdaptSlowV4,
%   PostAdaptSlowV4, AdaptSplitV4FastR/AdaptSplitV4FastL), not over the
%   earlier versions' names, so a visit run with the wrong version's
%   protocol script cannot silently load them, and their datlog file
%   names and fNIRS event prefixes identify the version. As in
%   GENERATEPROFILES_SPINALADAPTBOUTS, both fast-leg assignments of the
%   split profile are generated so Visit 2 never regenerates anything.
%   Does NOT generate the overground 6-minute walk test profile (see
%   GENERATEPROFILE_SIXMINUTEWALK).
%
%   NOTE: the tied-fast-to-split switch parses as a 'DccRamp2Split'
%   event (see PARSEEVENTSFROMSPEEDS), which NIRSHREFLEXARDUINOOPENLOOP-
%   WITHAUDIO relabels 'ChangeSpeedToSplit' because the belts are
%   already moving and tied on the stride before it: a silent fNIRS
%   marker with no "walk" cue and no pause, and not a second ramp row
%   for labTools' bout split. The tied-fast-to-tied-slow switch parses
%   as 'ChangeSpeedToSlow', likewise silent. In both, labTools' 'SS'
%   segment starts at the 'Mid' row, i.e., it includes the tied-fast
%   stride before the switch.
%
% Inputs:
%   slowSpeed    - double; slow belt speed (m/s), 50% of 6MWT speed
%   fastSpeed    - double; fast belt speed (m/s), 100% of 6MWT speed
%   fastestSpeed - double; fastest belt speed (m/s), 125% of 6MWT speed
%   profileDir   - char; path to directory where profiles are saved
%
% Outputs:
%   profileDir - char; path where profiles were saved (same as input)
%
% Toolbox Dependencies:
%   None
%
% See also GENERATEPROFILES_SPINALADAPTBOUTS,
%   RUNPROTOCOL_SPINALADAPTBOUTSV4, GENERATEPROFILE_SIXMINUTEWALK,
%   PARSEEVENTSFROMSPEEDS.

arguments
    slowSpeed    (1,1) double
    fastSpeed    (1,1) double
    fastestSpeed (1,1) double
    profileDir   (1,:) char
end

if ~exist(profileDir, 'dir')
    mkdir(profileDir);
end

%% Define H-Reflex Walking Calibration Constants
% NOTE: keep identical to GENERATEPROFILES_SPINALADAPTBOUTS (unchanged
% in Version 4.0).
calibStrides       = 400;   % strides; H-reflex calib trial length
calibSettleStrides = 5;     % strides; no-stim period at calib start

%% Generate H-Reflex Walking Calibration Profiles
% Build stim schedule: calibSettleStrides no-stim settle period, then
% stims at 2-stride intervals within each intensity level; 7-stride
% gap (6 rest strides + 1 stim) between intensity changes gives the
% experimenter time to adjust the stimulator knob.
stimSteps = [0 repmat(2, 1, 5), repmat([7 2 2 2 2 2], 1, 11)];
stimSteps = calibSettleStrides + cumsum(stimSteps);

% fast
velL = ones(calibStrides, 1) * fastSpeed;
velR = velL;
stimL = zeros(calibStrides, 1);
stimL(stimSteps) = 1;
stimR = stimL;
save(fullfile(profileDir, 'CalibrationFast.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

% slow
velL = ones(calibStrides, 1) * slowSpeed;
velR = velL;
save(fullfile(profileDir, 'CalibrationSlow.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Define Training Protocol Constants
boutsPerTrial   = 10;   % bouts per training trial
rampStrides     = 3;    % strides; speed ramp from rest at bout start
fastHoldStrides = 1;    % strides; tied-fast after the ramp, before the
                        % abrupt switch (one step on each leg)
ssStrides       = 10;   % strides; walking at target speeds per bout
boutRestStrides = 30;   % strides; max rest-pad between bouts
fastestStrides  = 50;   % strides; TiedFastest trial length, incl. ramp

%% Build Shared Bout Pieces
% Ramp: linear increase from rest to fastSpeed over rampStrides (tied).
rampFastBelt = (1:rampStrides)' / rampStrides * fastSpeed;
restPad      = zeros(boutRestStrides, 1);
ssStim       = ones(ssStrides, 1);

%% Build Tied Fastest Trial Profile (Tied Walking, 3-Stride Ramp, No Stim)
% Unchanged from GENERATEPROFILES_SPINALADAPTBOUTS: the bouts' 3-stride
% ramp from rest (its last stride already at fastestSpeed), then steady
% state -- 50 strides in all, no rest pad, no stim; runs on the plain
% audio-countdown controller (no fNIRS or H-reflex).
rampFastestBelt = (1:rampStrides)' / rampStrides * fastestSpeed;

velL  = [rampFastestBelt; ...
    ones(fastestStrides - rampStrides, 1) * fastestSpeed];
velR  = velL;
stimL = zeros(fastestStrides, 1);
stimR = stimL;
save(fullfile(profileDir, 'TiedFastest.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Pre-Adaptation Fast Bouts Profile (Tied Walking, 100%)
% Unchanged from GENERATEPROFILES_SPINALADAPTBOUTS. Structure per bout:
% ramp to fastSpeed | SS at fastSpeed | rest pad.
boutVelFast  = [rampFastBelt; ones(ssStrides, 1) * fastSpeed];
boutStimFast = [zeros(rampStrides, 1); ssStim];

[velL, stimL] = buildBoutTrial(boutVelFast, boutStimFast, restPad, ...
    boutsPerTrial);
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'PreAdaptFast.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Version 4.0 Bout Pieces (Tied-Fast Start, Abrupt Switch)
% Every Version 4.0 bout, on each belt: tied ramp to fastSpeed |
% fastHoldStrides at fastSpeed | ssStrides at that belt's target speed
% (fastSpeed or slowSpeed) | rest pad. No stim before the switch.
leadInFast    = [rampFastBelt; ones(fastHoldStrides, 1) * fastSpeed];
boutStimV4    = [zeros(rampStrides + fastHoldStrides, 1); ssStim];
boutVelV4Slow = [leadInFast; ones(ssStrides, 1) * slowSpeed];
boutVelV4Fast = [leadInFast; ones(ssStrides, 1) * fastSpeed];

%% Build Pre-Adaptation Slow Bouts Profile (Fast Start, Tied 50%)
[velL, stimL] = buildBoutTrial(boutVelV4Slow, boutStimV4, restPad, ...
    boutsPerTrial);
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'PreAdaptSlowV4.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Post-Adaptation Slow Bouts Profile (Fast Start, Tied 50%)
% Identical in content to PreAdaptSlowV4, saved as a separate file so
% its fNIRS event labels are distinguishable by epoch (pre- vs. post-
% adaptation) even though the belt-speed structure is the same.
save(fullfile(profileDir, 'PostAdaptSlowV4.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Adaptation Split Bouts Profiles (Both Fast-Leg Assignments)
% Fast-start split bout: both belts ramp tied to fastSpeed and hold for
% fastHoldStrides, then the slow-leg belt drops abruptly to slowSpeed
% while the fast-leg belt stays at fastSpeed. Both fast-leg assignments
% are generated up front (see GENERATEPROFILES_SPINALADAPTBOUTS).
[velSlow, stimSplit] = buildBoutTrial(boutVelV4Slow, boutStimV4, ...
    restPad, boutsPerTrial);
velFast = buildBoutTrial(boutVelV4Fast, boutStimV4, restPad, ...
    boutsPerTrial);
stimL = stimSplit;
stimR = stimSplit;

velR = velFast;    % right belt fast, left belt slow
velL = velSlow;
save(fullfile(profileDir, 'AdaptSplitV4FastR.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

velL = velFast;    % left belt fast, right belt slow
velR = velSlow;
save(fullfile(profileDir, 'AdaptSplitV4FastL.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

end

%% Local Functions

function [vel, stim] = buildBoutTrial(boutVel, boutStim, restPad, nBouts)
%BUILDBOUTTRIAL Concatenate nBouts repetitions of a single bout's speed
% and stim pattern, each followed by a rest pad.
%
%   Same as the local function of GENERATEPROFILES_SPINALADAPTBOUTS.
%
% Inputs:
%   boutVel  - Mx1 double; one bout's speed pattern
%   boutStim - Mx1 double; one bout's stim pattern
%   restPad  - Px1 double; rest-pad appended after every bout
%   nBouts   - scalar double; number of bouts to concatenate
%
% Outputs:
%   vel  - (nBouts*(M+P))x1 double; full-trial speed profile
%   stim - (nBouts*(M+P))x1 double; full-trial stim profile
%
% Toolbox Dependencies:
%   None
%
% See also GENERATEPROFILES_SPINALADAPTBOUTSV4.

vel  = repmat([boutVel;  restPad], nBouts, 1);
stim = repmat([boutStim; restPad], nBouts, 1);

end
