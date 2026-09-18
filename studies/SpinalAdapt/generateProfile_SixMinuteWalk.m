function profilePath = generateProfile_SixMinuteWalk(profileDir)
%GENERATEPROFILE_SIXMINUTEWALK Generate the self-paced 6-Minute Walk Test
% speed profile and save it to disk.
%
%   The 6MWT is self-paced (all-NaN velL/velR: no belt to control and no
%   target pace) and speed-independent, so it can be generated before the
%   N-Minute Walk Test speeds are known — unlike every other SpinalAdapt
%   profile, which is scaled from those speeds. Split out from
%   GENERATEPROFILES_SPINALADAPTBOUTS so the protocol script can create
%   this profile first, run the walk test, and only then compute speeds
%   and generate the rest of the session's profiles.
%
% Inputs:
%   profileDir - char; path to directory where the profile is saved
%
% Outputs:
%   profilePath - char; full path to the saved SixMinuteWalk.mat file
%
% Toolbox Dependencies:
%   None
%
% See also GENERATEPROFILES_SPINALADAPTBOUTS, RUNPROTOCOL_SPINALADAPTBOUTS.

if ~exist(profileDir, 'dir')
    mkdir(profileDir);
end

%% Generate Overground 6-Minute Walk Test Profile
% Self-paced (NaN) strides: this trial has no belt to control and no
% target pace, so the profile only needs to preallocate enough stride
% slots that indexing never runs out before the experimenter manually
% stops the trial via the GUI Stop button at six minutes.
sixMinWalkStrides = 1000;   % strides; margin above a fast per-leg
% cadence (~140 steps/min for 6 min = 840 steps) since trial length is
% experimenter-controlled, not profile-controlled
velL = nan(sixMinWalkStrides, 1);
velR = velL;
profilePath = fullfile(profileDir, 'SixMinuteWalk.mat');
save(profilePath, 'velL', 'velR');

end
