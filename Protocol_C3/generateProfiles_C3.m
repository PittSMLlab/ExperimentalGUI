function dirProfile = generateProfiles_C3(participantID,legSlow, ...
    speedOGMid,speedOGFast)
%GENERATEPROFILE_C3 Generate all velocity profiles for C3 study participant
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

dirWork = pwd();                    % get current (working) folder
% TODO: assuming Windows file system path delimiter, update to be agnostic
dirBase = ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles' ...
    '\Stroke_CCC'];
dirProfile = fullfile(dirBase,participantID,[upper(legSlow) '_Slow']);
if ~exist(dirProfile,'dir')         % if profile folder does not exist, ...
    mkdir(dirProfile)               % make it
end
cd(dirProfile);                     % change working directory

speedMean = 0.85 * speedOGMid;      % initialize mid speed to 85% 6MWT
speedFast = (4/3) * speedMean;      % compute fast speed as 33% greater
speedSlow = (2/3) * speedMean;      % compute slow speed as 33% lesser
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMMENT BELOW CONDITIONAL BLOCK IF PARTICIPANT REPORTS SPEEDS TOO SLOW %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if speedFast > 0.85*speedOGFast     % if fast speed exceeds threshold, ...
    disp('The fast speed conditional has been entered.');
    speedFast = 0.85 * speedOGFast; % saturate fast speed at threshold, and
    speedSlow = speedFast / 2;      % set slow speed at half fast speed
    speedMean = mean([speedFast speedSlow]);    % set mean speed to midpnt
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% TM Baseline Slow (50 strides) - NOT USED DURING C3 EXPERIMENT
% velL = speedSlow * ones(51,1);
% velR = velL;
% save('TM_Baseline_Slow','velL','velR');
% clear velL velR;

% TM Baseline Mid 1 (50 strides)
velL = speedMean * ones(51,1);
velR = velL;
save('TM_Baseline_Mid1','velL','velR');
clear velL velR;

% TM Baseline Fast (50 strides)
velL = speedFast * ones(51,1);
velR = velL;
save('TM_Baseline_Fast','velL','velR');
clear velL velR;

% OG Baseline Mid (150 strides)
velL = speedMean * ones(151,1);
velR = velL;
save('OG_Baseline_Mid','velL','velR');
clear velL velR;

% TM Short Exposure (Negative, 150 strides)
velL = speedMean*ones(50,1);        % initial tied-belt mid speed
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
velL = [velL; speedMean*ones(51,1)];% final tied-belt mid speed
velR = [velR; speedMean*ones(51,1)];
save('TM_ShortExposure_Neg','velL','velR');
clear velL velR;

% TM Short Exposure (Positive, 150 strides)
velL = speedMean*ones(50,1);        % initial tied-belt mid speed
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
velL = [velL; speedMean*ones(51,1)];% final tied-belt mid speed
velR = [velR; speedMean*ones(51,1)];
save('TM_ShortExposure_Pos','velL','velR');
clear velL velR;

% TM Baseline Mid 2 (150 strides)
velL = speedMean * ones(151,1);
velR = velL;
save('TM_Baseline_Mid2','velL','velR');
clear velL velR;

% TM Adaptation (150 strides each trial for six trials total)
if strncmpi(legSlow,'r',1)          % if right side is slow, ...
    velL = speedFast * ones(151,1);
    velR = speedSlow * ones(151,1);
else                                % otherwise, left side is slow, ...
    velL = speedSlow * ones(151,1);
    velR = speedFast * ones(151,1);
end
save('TM_Adaptation','velL','velR');
clear velL velR;

% OG or TM Post-Adaptation (150 strides each trial)
velL = speedMean * ones(151,1);
velR = velL;
save('PostAdaptation','velL','velR');
clear velL velR;

cd(dirWork);                        % reset working directory

end

