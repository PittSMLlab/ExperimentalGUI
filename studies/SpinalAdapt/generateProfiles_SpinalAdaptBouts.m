function profileDir = generateProfiles_SpinalAdaptBouts( ...
    slowSpeed, fastSpeed, fastestSpeed, profileDir, fastLeg)
%GENERATEPROFILES_SPINALADAPTBOUTS Generate speed and stim profiles for
% the SpinalAdapt protocol and save them to disk.
%
%   Generates speed (velL, velR) and H-reflex stimulus (stimL, stimR)
%   profiles for each condition in the SpinalAdapt bout-based protocol:
%   the overground 6-minute walk test, H-reflex walking calibration, the
%   tied fastest-speed trial, pre-adaptation, adaptation, and
%   post-adaptation bouts.
%
%   Revised 2026-09-18: familiarization removed; added a 50-stride tied
%   trial at fastestSpeed (150% of 6MWT); control bouts renamed/split
%   into PreAdaptFast (tied, 100%) and PreAdaptSlow (tied, 50%); split
%   bouts renamed AdaptSplit; PostAdaptSlow (5 blocks, tied, 50%) added.
%   Verify all parameters against the final approved protocol before
%   data collection begins. See History-PilotStudy2/ for the Pilot
%   Study 2 original.
%
% Inputs:
%   slowSpeed    - double; slow belt speed (m/s), 50% of 6MWT speed
%   fastSpeed    - double; fast belt speed (m/s), 100% of 6MWT speed
%   fastestSpeed - double; fastest belt speed (m/s), 150% of 6MWT speed
%   profileDir   - char; path to directory where profiles are saved
%   fastLeg      - char; 'R' or 'L' — which leg uses the fast belt speed
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
    fastLeg      (1,:) char {mustBeMember(fastLeg, {'R', 'L'})}
end

if ~exist(profileDir, 'dir')
    mkdir(profileDir);
end

%% Generate Overground 6-Minute Walk Test Profile
% Speed-independent (all-NaN, self-paced), so it is factored into its own
% function that the protocol script can call before speeds are known.
% Called here too so a full profile regeneration stays a single call.
generateProfile_SixMinuteWalk(profileDir);

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
% participant walks at this speed. The trailing rest pad is required:
% it gives the trial the same stop + silent-count ending as every other
% block and is the controller's only clean self-termination path after
% the final walking stride.
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

%% Build Adaptation Split Bouts Profile
% Structure per bout: split ramp | SS at fast/slow speeds | rest pad.
% Default: right belt fast, left belt slow; swap if fastLeg = 'L'.
boutStimSplit = [zeros(rampStrides, 1); ssStim];

[velL, stimL] = buildBoutTrial(boutVelSlow, boutStimSplit, restPad, ...
    boutsPerTrial);
[velR, stimR] = buildBoutTrial(boutVelFast, boutStimSplit, restPad, ...
    boutsPerTrial);

if strcmp(fastLeg, 'L')     % swap leg profiles if left is fast
    temp = velR;
    velR = velL;
    velL = temp;
end
save(fullfile(profileDir, 'AdaptSplit.mat'), ...
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
