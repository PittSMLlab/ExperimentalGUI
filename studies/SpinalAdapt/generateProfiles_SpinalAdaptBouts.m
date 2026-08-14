function profileDir = generateProfiles_SpinalAdaptBouts( ...
    slowSpeed, fastSpeed, profileDir, fastLeg)
%GENERATEPROFILES_SPINALADAPTBOUTS Generate speed and stim profiles for
% the SpinalAdapt protocol and save them to disk.
%
%   Generates speed (velL, velR) and H-reflex stimulus (stimL, stimR)
%   profiles for each condition in the SpinalAdapt bout-based protocol:
%   H-reflex walking calibration, familiarization, control, and split
%   bouts.
%
%   TEMPLATE — Updated with new SpinalAdapt protocol bout structure
%   (3-stride ramp + 10-stride SS per bout, 10 bouts per trial,
%   8 split trials). Verify all parameters against the final approved
%   protocol specification before data collection begins.
%   See History-PilotStudy2/ for the Pilot Study 2 original.
%
% Inputs:
%   slowSpeed  - double; slow belt speed (m/s)
%   fastSpeed  - double; fast belt speed (m/s)
%   profileDir - char; path to directory where profiles are saved
%   fastLeg    - char; 'R' or 'L' — which leg uses the fast belt speed
%
% Outputs:
%   profileDir - char; path where profiles were saved (same as input)
%
% Toolbox Dependencies:
%   None
%
% See also RUNPROTOCOL_SPINALADAPTBOUTS, RUNWALKINGCALIBRATIONS.

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
boutsPerTrialFam = 5;    % bouts per familiarization trial
boutsPerTrial    = 10;   % bouts per training trial
rampStrides      = 3;    % strides; speed ramp from rest at bout start
ssStrides        = 10;   % strides; steady-state walking per bout
boutRestStrides  = 30;   % strides; max rest-pad between bouts
boutStimPeriod   = 5;    % strides; H-reflex stim cycle during SS

%% Build Per-Bout Speed and Stim Vectors
% Ramp: linear increase from rest to target speed over rampStrides.
rampFastBelt = (1:rampStrides)' / rampStrides * fastSpeed;
rampSlowBelt = (1:rampStrides)' / rampStrides * slowSpeed;

% Stim during SS: one pulse at the start of each boutStimPeriod.
boutStimCycle = ones(boutStimPeriod,1);
ssStim = repmat(boutStimCycle, ssStrides / boutStimPeriod, 1);
restPad = zeros(boutRestStrides, 1);

%% Build Familiarization Bouts Profile (Tied Walking)
% Structure per bout: ramp to tied | SS at tied | rest pad.
boutVelSlowFam  = [rampSlowBelt; ones(ssStrides, 1) * slowSpeed];
boutVelFastFam  = [rampFastBelt; ones(ssStrides, 1) * fastSpeed];
boutStimFam = [zeros(rampStrides, 1); ssStim];

velL = [];  stimL = [];
for ii = 1:boutsPerTrialFam
    velL  = [velL;  boutVelSlowFam; restPad];
    stimL = [stimL; boutStimFam; restPad];
end
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'FamBoutsSlow.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

velL = [];  stimL = [];
for ii = 1:boutsPerTrialFam
    velL  = [velL;  boutVelFastFam; restPad];
    stimL = [stimL; boutStimFam; restPad];
end
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'FamBoutsFast.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Control Bouts Profile (Tied Walking)
% Structure per bout: ramp to fastSpeed | SS at fastSpeed | rest pad.
boutVelCtrl  = [rampFastBelt; ones(ssStrides, 1) * fastSpeed];
boutStimCtrl = [zeros(rampStrides, 1); ssStim];

velL = [];  stimL = [];
for ii = 1:boutsPerTrial
    velL  = [velL;  boutVelCtrl; restPad];
    stimL = [stimL; boutStimCtrl; restPad];
end
velR  = velL;
stimR = stimL;
save(fullfile(profileDir, 'CtrlBouts.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

%% Build Split Bouts Profile
% Structure per bout: split ramp | SS at fast/slow speeds | rest pad.
% Default: right belt fast, left belt slow; swap if fastLeg = 'L'.
boutVelFast  = [rampFastBelt; ones(ssStrides, 1) * fastSpeed];
boutVelSlow  = [rampSlowBelt; ones(ssStrides, 1) * slowSpeed];
boutStimSplit = [zeros(rampStrides, 1); ssStim];

velL = [];  velR = [];  stimL = [];
for ii = 1:boutsPerTrial
    velL  = [velL;  boutVelSlow; restPad];
    velR  = [velR;  boutVelFast; restPad];
    stimL = [stimL; boutStimSplit; restPad];
end
stimR = stimL;

if strcmp(fastLeg, 'L')     % swap leg profiles if left is fast
    temp = velR;
    velR = velL;
    velL = temp;
end
save(fullfile(profileDir, 'SplitBouts.mat'), ...
    'velL', 'velR', 'stimL', 'stimR');

end
