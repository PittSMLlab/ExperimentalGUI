function transferDataAndSaveC3D_PC2_C3(participantID,isSession1,indsTrials)
%TRANSFERDATAANDSAVEC3D_PC2_C3 Transfer PC2 data and save C3D files for C3
%   This function accepts the participant ID and a boolean indicating the
% session as input arguments and recursively transfers all data to the
% server (including creating non-existant folders if necessary) and exports
% the transferred files to the C3D format using the Vicon Nexus SDK.
%
% input(s):
%   participantID: string or character array of the ID (e.g., 'C3S15')
%   isSession1: boolean indicating whether the current session is session 1
%   indsTrials: (optional) indices of the trials to export to C3D; if
%       omitted, all trials are processed

if nargin == 0 %no input provided
    answer = inputdlg({'SubjectID (e.g., C3S01)','Session (1 or 2)','Trials to copy (default empty, integer vector, e.g., [1,3,5]))'},...
    'Copy PC2 Data to Server',[1 45; 1 45; 1 45],...
    {'C3S01','1','[ ]'});
    participantID = answer{1};
    indsTrials = eval(answer{3});
    if strcmp(answer{2},'1')
        isSession1 = true;
    else
        isSession1 = false;
    end
else
    % TODO: update function to open a GUI for user input if no inputs provided
    narginchk(2,3);         % verify correct number of input arguments
    % set default for indsTrials if not provided
    if nargin < 3
        indsTrials = [];    % empty to indicate all trials
    end
end

% determine session name based on boolean input
sess = 'Session1';
if ~isSession1          % if current session is second walking session, ...
    sess = 'Session2';
end

% define data paths based on input parameters
dirPC2Data = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'Stroke_CCC'],participantID,sess);
dirSrvrC3 = 'W:\Nathan\C3';
dirSrvrData = fullfile(dirSrvrC3,'Data',participantID);
dirSrvrRaw = fullfile(dirSrvrC3,'RawBackupData',participantID,sess);

% define source and destination paths in specified order
srcs = {dirPC2Data dirPC2Data};
dests = {fullfile(dirSrvrData,sess,'PC2') fullfile(dirSrvrRaw,'PC2')};

% check if PC2 data directory exists, else raise a warning
if ~isfolder(dirPC2Data)
    error('PC2 data directory does not exist: %s\n',dirPC2Data);
end

% transfer data using utility function with error handling
try
    utils.transferDataSess(srcs,dests);         % transfer data
catch ME
    warning(ME.identifier,'Data transfer failed: %s\n',ME.message);
    return;
end

% check if destination directory was created and populated
if ~isfolder(fullfile(dirSrvrData,sess,'PC2'))
    error('Data transfer unsuccessful; destination folder not found.');
end

% export session trials to C3D using dataMotion functions
try
    dataMotion.exportSessionToC3D(fullfile(dirSrvrData,sess,'PC2'),indsTrials);
catch ME
    warning(ME.identifier,'Error exporting to C3D: %s\n',ME.message);
end

end

