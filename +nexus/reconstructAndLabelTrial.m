function reconstructAndLabelTrial(pathTrial)
%RECONSTRUCTANDLABEL Run reconstruct and label pipeline and save trial
%   This function accepts as input the full path to the trial to process by
% running the reconstruct and label pipeline and saving the processed
% trial.
%
% input(s):
%   pathTrial: string or character array of the full path of the trial on
%       which to run the reconstruct and label processing pipeline
% output(s):

% This script uses Vicon Nexus SDK to load a trial, run reconstruct, and
% label the data. Make sure the Vicon Nexus SDK is installed and added to 
% the MATLAB path.

% TODO: add a GUI input option if helpful
narginchk(1,1);         % verify correct number of input arguments

fprintf('Loading trial from %s...\n',pathTrial);
try                     % try loading trial data
    vicon.OpenTrial(pathTrial);
    fprintf('Trial loaded successfully.\n');
catch ME
    fprintf('Error loading trial: %s\n',ME.message);
    return;
end

% The reconstruct step will process the raw camera data and reconstruct 3D
% marker positions. This must be done before labeling.
fprintf('Running reconstruction pipeline...\n');
try                     % try running reconstruct pipeline
    vicon.Reconstruct();
    fprintf('Reconstruction complete.\n');
catch ME
    fprintf('Error during reconstruction: %s\n',ME.message);
end

% The labeling step assigns names to the reconstructed markers based on
% the Vicon Nexus labeling scheme.
fprintf('Running labeling pipeline...\n');
try                     % try running the label pipeline
    vicon.Label();
    fprintf('Labeling complete.\n');
catch ME
    fprintf('Error during labeling: %s\n',ME.message);
end

% Saves the changes made (reconstruction and labeling) back to trial file
% TODO: is this what happens in the current pipeline? Is it saved to C3D?
fprintf('Saving the trial...\n');
try                     % try saving the processed trial
    vicon.SaveTrial();
    fprintf('Trial saved successfully.\n');
catch ME
    fprintf('Error saving trial: %s\n',ME.message);
end

% Specify the path and filename for the C3D file (assuming 'pathTrial'
% already contains 'trial##' and only need to add extension)
pathC3D = fullfile(pathTrial,'.c3d');  % Example file path

fprintf('Exporting to C3D file: %s\n',pathC3D);
try                     % try exporting the C3D file
    vicon.ExportC3D(pathC3D);
    fprintf('C3D file exported successfully.\n');
catch ME
    fprintf('Error exporting to C3D: %s\n',ME.message);
end

end

