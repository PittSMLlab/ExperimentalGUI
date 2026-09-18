function profileDir = generateProfiles_SpinalAdaptBouts( ...
    slowSpeed, fastSpeed, fastestSpeed, profileDir)
%GENERATEPROFILES_SPINALADAPTBOUTS Generate speed and stim profiles for
% the SpinalAdapt protocol and save them to disk.
%
%   Generates speed (velL, velR) and H-reflex stimulus (stimL, stimR)
%   profiles for each condition in the SpinalAdapt bout-based protocol:
%   H-reflex walking calibration, the tied fastest-speed trial,
%   pre-adaptation, adaptation, and post-adaptation bouts. Does NOT
%   generate the overground 6-minute walk test profile -- that is
%   speed-independent and generated separately, earlier, by
%   GENERATEPROFILE_SIXMINUTEWALK (called directly from
%   RUNPROTOCOL_SPINALADAPTBOUTS, before this function, since the walk
%   test must run before these speeds are even known).
%
%   Revised 2026-09-18: familiarization removed; added a 50-stride tied
%   trial at fastestSpeed (150% of 6MWT); control bouts renamed/split
%   into PreAdaptFast (tied, 100%) and PreAdaptSlow (tied, 50%); split
%   bouts renamed AdaptSplit; PostAdaptSlow (5 blocks, tied, 50%) added.
%   Revised again 2026-09-18 for the two-visit protocol: the adaptation
%   split profile is generated for BOTH possible fast-leg assignments
%   (AdaptSplitFastR.mat, AdaptSplitFastL.mat) rather than taking a
%   fastLeg input, since visit 2 reuses visit 1's profiles with the fast
%   leg flipped and must not need to regenerate anything --
%   RUNPROTOCOL_SPINALADAPTBOUTS picks the file matching each visit's
%   confirmed fast leg at run time. Verify all parameters against the
%   final approved protocol before data collection begins. See
%   History-PilotStudy2/ for the Pilot Study 2 original.
%
% Inputs:
%   slowSpeed    - double; slow belt speed (m/s), 50% of 6MWT speed
%   fastSpeed    - double; fast belt speed (m/s), 100% of 6MWT speed
%   fastestSpeed - double; fastest belt speed (m/s), 150% of 6MWT speed
%   profileDir   - char; path to directory where profiles are saved
%
% Outputs:
%   profileDir - char; path where profiles were saved (same as input)
%
% Toolbox Dependencies:
%   None
%
% See also GENERATEPROFILE_SIXMINUTEWALK, RUNPROTOCOL_SPINALADAPTBOUTS,
%   RUNWALKINGCALIBRATIONS.

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
ssStrides       = 10;   % strides; steady-state walking per bout
boutRestStrides = 30;   % strides; max rest-pad between bouts
fastestStrides  = 50;   % strides; TiedFastest trial length, no ramp

%% Build Per-Bout Speed and Stim Vectors
% Ramp: linear increase from rest to target speed over rampStrides.
rampFastBelt = (1:rampStrides)' / rampStrides * fastSpeed;
rampSlowBelt = (1:rampStrides)' / rampStrides * slowSpeed;

% Stim during SS: every steady-state stride is stimulated on both legs.
ssStim  = ones(ssStrides, 1);
restPad = zeros(boutRestStrides, 1);

%% Build Tied Fastest Trial Profile (Tied Walking, No Ramp, No Stim)
% Structure: 50 SS strides at fastestSpeed | rest pad. No ramp (straight
% to steady state) and no stim — the only time in the session the
% participant walks at this speed. The trailing rest pad is required
% regardless: it is the controller's only clean self-termination path
% after the final walking stride. Unlike every other block, this trial's
% belt-stop uses a spoken "treadmill will stop in 3-2-1" warning instead
% of the "stop" + silent-count-forward ending (RunProtocol_
% SpinalAdaptBouts.m sets useStartStopCountdown = true only for this
% trial), since fNIRS is not recording yet at this point in the session.
velFastest  = ones(fastestStrides, 1) * fastestSpeed;
stimFastest = zeros(fastestStrides, 1);
velL  = [velFastest;  restPad];
velR  = velL;
stimL = [stimFastest; restPad];
stimR = stimL;
save(fullfile(profileDir, 'TiedFastest.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Pre-Adaptation Fast Bouts Profile (Tied Walking, 100%)
% Structure per bout: ramp to fastSpeed | SS at fastSpeed | rest pad.
boutVelFast  = [rampFastBelt; ones(ssStrides, 1) * fastSpeed];
boutStimFast = [zeros(rampStrides, 1); ssStim];

[velL, stimL] = buildBoutTrial(boutVelFast, boutStimFast, restPad, ...
    boutsPerTrial);
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'PreAdaptFast.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Pre-Adaptation Slow Bouts Profile (Tied Walking, 50%)
% Structure per bout: ramp to slowSpeed | SS at slowSpeed | rest pad.
boutVelSlow  = [rampSlowBelt; ones(ssStrides, 1) * slowSpeed];
boutStimSlow = [zeros(rampStrides, 1); ssStim];

[velL, stimL] = buildBoutTrial(boutVelSlow, boutStimSlow, restPad, ...
    boutsPerTrial);
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'PreAdaptSlow.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Post-Adaptation Slow Bouts Profile (Tied Walking, 50%)
% Identical in content to PreAdaptSlow, saved as a separate file so its
% fNIRS event labels are distinguishable by epoch (pre- vs. post-
% adaptation) even though the belt-speed structure is the same.
[velL, stimL] = buildBoutTrial(boutVelSlow, boutStimSlow, restPad, ...
    boutsPerTrial);
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'PostAdaptSlow.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Adaptation Split Bouts Profiles (Both Fast-Leg Assignments)
% Structure per bout: split ramp | SS at fast/slow speeds | rest pad.
% Both possible fast-leg assignments are generated up front, as separate
% files, rather than taking a fastLeg input: the two-visit protocol
% flips which leg is fast between visit 1 and visit 2 (paretic slow in
% visit 1, non-paretic slow in visit 2) while reusing every other
% profile, so RUNPROTOCOL_SPINALADAPTBOUTS just selects the file
% matching each visit's confirmed fast leg at run time and neither visit
% ever needs to regenerate anything.
boutStimSplit = [zeros(rampStrides, 1); ssStim];

[velSlow, stimSplit] = buildBoutTrial(boutVelSlow, boutStimSplit, ...
    restPad, boutsPerTrial);
velFast = buildBoutTrial(boutVelFast, boutStimSplit, restPad, ...
    boutsPerTrial);

velR = velFast;    % right belt fast, left belt slow
velL = velSlow;
stimL = stimSplit;
stimR = stimSplit;
save(fullfile(profileDir, 'AdaptSplitFastR.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

velL = velFast;    % left belt fast, right belt slow
velR = velSlow;
save(fullfile(profileDir, 'AdaptSplitFastL.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

end

%% Local Functions

function [vel, stim] = buildBoutTrial(boutVel, boutStim, restPad, nBouts)
%BUILDBOUTTRIAL Concatenate nBouts repetitions of a single bout's speed
% and stim pattern, each followed by a rest pad.
%
%   Factors out the repeated ramp | SS | rest-pad accumulation shared by
%   every bout-based trial in this file.
%
% Inputs:
%   boutVel  - Mx1 double; one bout's speed pattern (ramp + SS)
%   boutStim - Mx1 double; one bout's stim pattern (ramp + SS)
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
% See also GENERATEPROFILES_SPINALADAPTBOUTS.

vel  = repmat([boutVel;  restPad], nBouts, 1);
stim = repmat([boutStim; restPad], nBouts, 1);

end
