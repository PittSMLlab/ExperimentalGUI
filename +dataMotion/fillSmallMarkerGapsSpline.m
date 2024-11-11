function fillSmallMarkerGapsSpline(markerGaps,pathTrial,vicon,maxGapSize)
%FILLSMALLMARKERGAPSSPLINE Fills small marker trajectory gaps via spline
%   This function fills gaps in all marker trajectories identified in
% markerGaps using spline interpolation for gaps smaller than the specified
% maxGapSize variable. It optionally accepts a Vicon Nexus SDK object.
%
% input(s):
%   markerGaps: struct with start and end frame indices of gaps in each
%       marker's trajectory, as obtained from extractMarkerGapsTrial
%   pathTrial: string or character array of the full path to the trial
%   vicon: (optional) Vicon Nexus SDK object; connects if not supplied
%   maxGapSize: (optional) integer specifying maximum gap size to fill,
%       (default: 10 frames)

% TODO: add a GUI input option if helpful
narginchk(2,4);         % verify correct number of input arguments

% set default value for maxGapSize if not provided
if nargin < 4 || isempty(maxGapSize)
    maxGapSize = 10;
end

% initialize the Vicon Nexus object if not provided
if nargin < 3 || isempty(vicon)
    fprintf(['No Vicon SDK object provided. Connecting to Vicon ' ...
        'Nexus...\n']);
    vicon = ViconNexus();
end

% open the trial if not already open
if ~dataMotion.openTrialIfNeeded(pathTrial,vicon)
    return;  % exit if the trial could not be opened
end

% get subject name (assuming only one subject in the trial)
subject = vicon.GetSubjectNames();
if isempty(subject)
    error('No subject found in the trial.');
end
subject = subject{1};

% process each marker gap in the markerGaps struct
markers = fieldnames(markerGaps);
for mrkr = 1:length(markers)
    nameMarker = markers{mrkr};      % get marker name
    gaps = markerGaps.(nameMarker);  % retrieve gap indices for marker

    % get marker trajectory data
    [trajX,trajY,trajZ,existsTraj] = ...
        vicon.GetTrajectory(subject,nameMarker);

    % process and fill gaps smaller than maxGapSize
    for indGap = 1:size(gaps,1)
        gapStart = gaps(indGap,1);
        gapEnd = gaps(indGap,2);
        gapLength = gapEnd - gapStart + 1;

        % fill gap if it is within the allowed maxGapSize
        if gapLength <= maxGapSize
            [trajX,trajY,trajZ,existsTraj] = ...
                fillGap(trajX,trajY,trajZ,existsTraj,gaps(indGap,:));
        end
    end

    % update trajectory in Vicon Nexus
    vicon.SetTrajectory(subject,nameMarker,trajX,trajY,trajZ,existsTraj);
end

% saves the changes made back to the trial file
fprintf('Saving the trial...\n');
try                     % try saving the processed trial
    vicon.SaveTrial(200);
    fprintf('Trial saved successfully.\n');
catch ME
    warning(ME.identifier,'%s',ME.message);
end

end

function [trajX,trajY,trajZ,existsTraj] = fillGap( ...
    trajX,trajY,trajZ,existsTraj,gapRange)
% FILLGAP Interpolates a gap in a marker trajectory using spline
% input:
%   trajX, trajY, trajZ: trajectories for x, y, and z coordinates
%   existsTraj: logical array indicating frame existence
%   gapRange: 1x2 array with start and end indices of the gap to fill

% frames to process for filling the gap
framesToFill = gapRange(1):gapRange(2);
existingFrames = find(existsTraj);      % get frames with data

% interpolate missing frames
trajX(framesToFill) = interp1(existingFrames,trajX(existingFrames),framesToFill,'spline');
trajY(framesToFill) = interp1(existingFrames,trajY(existingFrames),framesToFill,'spline');
trajZ(framesToFill) = interp1(existingFrames,trajZ(existingFrames),framesToFill,'spline');
existsTraj(framesToFill) = true;        % update existence array

end

