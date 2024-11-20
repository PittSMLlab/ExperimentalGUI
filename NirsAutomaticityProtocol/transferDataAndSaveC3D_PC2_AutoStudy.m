function transferDataAndSaveC3D_PC2_AutoStudy()
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

answer = inputdlg({'SubjectID (e.g., AUC01)','VisitNum (1,2, 3, or 4)','StudyName (e.g.,YANIRSAutomaticityStudy)','Trials to copy (default empty, integer vector, e.g., [1,3,5]))'},...
    'Copy PC2 Data to Server',[1 45; 1 45; 1 45; 1 45],...
    {'AUC10','1','YANIRSAutomaticityStudy','[ ]'});
participantID = answer{1};
visitNum = sprintf('V0%d',str2num(answer{2}));
if strcmp(visitNum,'V0') %input incorrect, something that's not a number was inputed, throw an error
    error('Invalid input given, visit number should be a single digit number')
end
studyName = answer{3};
indsTrials = eval(answer{4});

% define data paths based on input parameters
dirPC2Data = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    studyName],participantID,visitNum);
dirSrvrData = fullfile('W:\Shuqi\YANirsAutomaticityStudy\Data',participantID, visitNum);
dirSrvrRaw = fullfile('W:\Shuqi\DataBackup\YANirsAutomaticityStudy',participantID,visitNum);
fprintf('\nTransfering data from %s \nto %s\nAnd to backup folder: %s\n', dirPC2Data,dirSrvrData,dirSrvrRaw);

% define source and destination paths in specified order
srcs = {dirPC2Data dirPC2Data};
dests = {fullfile(dirSrvrData,'PC2') fullfile(dirSrvrRaw,'PC2')};

% check if PC2 data directory exists, else raise a warning
if ~isfolder(dirPC2Data)
    error('PC2 data directory does not exist: %s\n',dirPC2Data);
end

% transfer data using utility function with error handling
try
    fprintf('...Copying data to the server...\n')
    utils.transferDataSess(srcs,dests);         % transfer data
catch ME
    warning(ME.identifier,'Data transfer failed: %s\n',ME.message);
    return;
end

% check if destination directory was created and populated
if ~isfolder(fullfile(dirSrvrData,'PC2'))
    error('Data transfer unsuccessful; destination folder not found.');
end

% export session trials to C3D using dataMotion functions
try
    fprintf('...Exporting file to c3d...\n')
    dataMotion.exportSessionToC3D(fullfile(dirSrvrData,'PC2'),indsTrials);
catch ME
    warning(ME.identifier,'Error exporting to C3D: %s\n',ME.message);
end

end

