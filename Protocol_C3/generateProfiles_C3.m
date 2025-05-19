function dirProfile = generateProfiles_C3(participantID,legSlow, ...
    speedOGMid,speedOGFast)
%GENERATEPROFILE_C3 Generate and save velocity profiles for the C3 study
%   This function takes as input the participant ID, slow leg, middle, and
% fast walking speeds, and generates MAT files containing the velocities
% for the left and right legs (i.e., the required speed profiles) for each
% context specificity, cognition, and connectivity (C3) study experiment
% trial type (i.e., baseline slow, baseline mid, baseline fast, short
% exposure - positive, short exposure - negative, baseline mid 2,
% adaptation, and post-adaptation). NOTE: NWB wanted to keep inputs similar
% to function ('Gen_Profiles_C3') used for participants C3S01-13.
%
% input:
%   participant: string or character array of participant ID (i.e., 'C3S01'
%       for participant with stroke 01)
%   legSlow: string or character array (formerly 'sideAffected', either 'R'
%       or 'L' case insensitive)
%   speedOGMid: double scalar of the self-selected comfortable OG walking
%       speed from the 6-Minute Walk Test
%   speedOGFast: double scalar of the fast OG walking speed computed as the
%       mean of the last 10-Meter Walk Test speeds
% output:
%   profileDir: string or character array of the folder to which the MAT
%       profile files are saved

% define base directories and output folder path
dirBase = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles' ...
    '\Stroke_CCC'];
dirProfile = fullfile(dirBase,participantID,[upper(legSlow) '_Slow']);
if ~isfolder(dirProfile)            % if profile folder does not exist, ...
    mkdir(dirProfile)               % make it
end

% define speeds with adjustments for thresholds
speedMean = 0.85 * speedOGMid;      % initialize mid speed to 85% 6MWT
% fast speed is minimum of 4/3 mean speed or 85% OG fast speed
speedFast = min((4/3) * speedMean, 0.85 * speedOGFast);
speedSlow = speedFast / 2;          % compute slow speed for 2:1 ratio
speedMean = mean([speedFast speedSlow]);    % set mean to midpoint speed

% define profiles and save using the helper function
numStrides = struct('short',51,'long',151);

% TM Baseline Slow (50 strides) - NOT USED DURING C3 EXPERIMENT
% velL = speedSlow * ones(numStrides.short,1);
% velR = velL;
% save(fullfile(dirProfile,'TM_Baseline_Slow'),'velL','velR');

% TM Baseline Mid 1 (50 strides)
velL = speedMean * ones(numStrides.short,1);
velR = velL;
save(fullfile(dirProfile,'TM_Baseline_Mid1'),'velL','velR');

% TM Baseline Fast (50 strides)
velL = speedFast * ones(numStrides.short,1);
velR = velL;
save(fullfile(dirProfile,'TM_Baseline_Fast'),'velL','velR');

% OG Baseline Mid (150 strides)
velL = speedMean * ones(numStrides.long,1);
velR = velL;
save(fullfile(dirProfile,'OG_Baseline_Mid'),'velL','velR');

% TM Short Exposure (Negative, 150 strides)
velL = speedMean*ones(numStrides.short-1,1);% initial tied-belt mid speed
velR = velL;
if strncmpi(legSlow,'r',1)          % if right side slow, ...
    % ramp speed for 20 strides followed by 30 strides at full difference
    % left side slow, right side fast
    velL = [velL; linspace(speedMean,speedSlow,20)'; speedSlow*ones(30,1)];
    velR = [velR; linspace(speedMean,speedFast,20)'; speedFast*ones(30,1)];
else    % otherwise, left side fast, right side slow
    velL = [velL; linspace(speedMean,speedFast,20)'; speedFast*ones(30,1)];
    velR = [velR; linspace(speedMean,speedSlow,20)'; speedSlow*ones(30,1)];
end
velL = [velL; speedMean*ones(numStrides.short,1)];  % final tied-belt mid
velR = [velR; speedMean*ones(numStrides.short,1)];
save(fullfile(dirProfile,'TM_ShortExposure_Neg'),'velL','velR');

% TM Short Exposure (Positive, 150 strides)
velL = speedMean*ones(numStrides.short-1,1);% initial tied-belt mid speed
velR = velL;
if strncmpi(legSlow,'r',1)          % if right side slow, ...
    % ramp speed for 20 strides followed by 30 strides at full difference
    % left side fast, right side slow
    velL = [velL; linspace(speedMean,speedFast,20)'; speedFast*ones(30,1)];
    velR = [velR; linspace(speedMean,speedSlow,20)'; speedSlow*ones(30,1)];
else    % otherwise, left side slow, right side fast
    velL = [velL; linspace(speedMean,speedSlow,20)'; speedSlow*ones(30,1)];
    velR = [velR; linspace(speedMean,speedFast,20)'; speedFast*ones(30,1)];
end
velL = [velL; speedMean*ones(numStrides.short,1)];  % final tied-belt mid
velR = [velR; speedMean*ones(numStrides.short,1)];
save(fullfile(dirProfile,'TM_ShortExposure_Pos'),'velL','velR');

% TM Baseline Mid 2 (150 strides)
velL = speedMean * ones(numStrides.long,1);
velR = velL;
save(fullfile(dirProfile,'TM_Baseline_Mid2'),'velL','velR');

% TM Adaptation (150 strides each trial for six trials total)
if strncmpi(legSlow,'r',1)          % if right side is slow, ...
    velL = speedFast * ones(numStrides.long,1);
    velR = speedSlow * ones(numStrides.long,1);
else                                % otherwise, left side is slow, ...
    velL = speedSlow * ones(numStrides.long,1);
    velR = speedFast * ones(numStrides.long,1);
end
save(fullfile(dirProfile,'TM_Adaptation'),'velL','velR');

% TM Adaptation / Split-Walking Bouts (Session 2, 150 strides)
velL = speedMean*ones(25,1);        % initial tied-belt mid speed
velR = velL;
if strncmpi(legSlow,'r',1)          % if right side slow, ...
    % left side fast, right side slow
    velL = [velL; speedFast * ones(100,1)];         % 100 strides split 2:1
    velR = [velR; speedSlow * ones(100,1)];
else    % otherwise, left side slow, right side fast
    velL = [velL; speedSlow * ones(100,1)];
    velR = [velR; speedFast * ones(100,1)];
end
velL = [velL; speedMean * ones(26,1)];              % final tied-belt mid
velR = [velR; speedMean * ones(26,1)];
save(fullfile(dirProfile,'TM_SplitBout'),'velL','velR');
velL = [velL(1:125); velL(125)];
velR = [velR(1:125); velR(125)];
save(fullfile(dirProfile,'TM_SplitBout_Short'),'velL','velR');

% OG or TM Post-Adaptation (150 strides each trial)
velL = speedMean * ones(numStrides.long,1);
velR = velL;
save(fullfile(dirProfile,'PostAdaptation'),'velL','velR');

% OG Post-Adaptation Long Trial
velL = speedMean * ones(176,1);
velR = velL;
save(fullfile(dirProfile,'PostAdaptation_Long'),'velL','velR');

end

