function transferData_SpinalAdapt(participantID,threshTime)
%TRANSFERDATA_SPINALADAPT Transfer PC1 data for the Spinal Adaptation study
%   This function accepts the participant ID and recursively transfers all
% data to the server (including creating non-existant folders if necessary)
% and creates folders that will be needed for future analysis.
%
% input(s):
%   participantID: string or character array of the ID (e.g., 'SABH##')

% TODO: update function to open a GUI for user input if no inputs provided
narginchk(2,2);         % verify correct number of input arguments

% TODO: add error checks and set default value for 'threshTime'

% define data paths based on input parameters
dirExpGUI = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI';
dirProfiles = fullfile(dirExpGUI,'profiles','SpinalAdaptNirsStudy', ...
    participantID);
dirNIRS = 'C:\Users\cntctsml\Documents\Oxysoft Data\SpinalAdaptStudy';
dirData = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'SpinalAdaptStudy'],participantID,'New Session');
dirSrvrSpinalAdapt = 'W:\SpinalAdaptStudy';
dirSrvrData = fullfile(dirSrvrSpinalAdapt,'Data',participantID);
dirSrvrRaw = fullfile(dirSrvrSpinalAdapt,'RawBackupData',participantID);

% define source and destination paths in specified order
srcs = {dirData ...
    dirProfiles fullfile(dirNIRS,participantID) ...
    dirData fullfile(dirNIRS,participantID) ...
    fullfile(dirExpGUI,'datlogs') fullfile(dirExpGUI,'datlogs')};
dests = {fullfile(dirSrvrData,'Vicon') ...
    fullfile(dirSrvrData,'SpeedProfiles') fullfile(dirSrvrData,'NIRS') ...
    fullfile(dirSrvrRaw,'Vicon') fullfile(dirSrvrRaw,'NIRS') ...
    fullfile(dirSrvrData,'DataLogs') fullfile(dirSrvrRaw,'DataLogs')};

% check if PC1 data directory exists, else raise a warning
if ~isfolder(dirData)
    error('PC1 data directory does not exist: %s\n',dirData);
end

% transfer data using utility function with error handling
try
    utils.transferDataSess(srcs,dests,threshTime);  % transfer data
catch ME
    warning(ME.identifier,'Data transfer failed: %s\n',ME.message);
    return;
end

% check if destination directory was created and populated
if ~isfolder(fullfile(dirSrvrData,'Vicon'))
    error('Data transfer unsuccessful; destination folder not found.');
end

% TODO: update to automatically rename data logs by trial name for C3D2MAT

pathsCreate = {
    fullfile(dirSrvrData,'Results')
    fullfile(dirSrvrData,'SyncFiles')
    fullfile(dirSrvrData,'NASATLX')
    };

for p = 1:length(pathsCreate)       % for each path to create, ...
    if ~isfolder(pathsCreate{p})    % if does not already exist, ...
        mkdir(pathsCreate{p});      % create it
    end
end

end

