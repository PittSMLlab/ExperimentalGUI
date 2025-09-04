function transferData_PC1_C3(participantID,isSession1,threshTime)
%TRANSFERDATA_PC1_C3 Transfer PC1 data for the C3 study
%   This function accepts the participant ID and a boolean indicating the
% session as input arguments and recursively transfers all data to the
% server (including creating non-existant folders if necessary) and creates
% folders that will be needed for future processing and analysis.
%
% input(s):
%   participantID: string or character array of the ID (e.g., 'C3S15')
%   isSession1: boolean indicating whether the current session is session 1

% TODO: update function to open a GUI for user input if no inputs provided
narginchk(3,3);         % verify correct number of input arguments

% TODO: add error checks and set default value for 'threshTime'

% determine session name based on boolean input
sess = 'Session1';
if ~isSession1          % if current session is second walking session, ...
    sess = 'Session2';
end

% define data paths based on input parameters
dirPC1ExpGUI = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI';
dirPC1Profiles = fullfile(dirPC1ExpGUI,'profiles','Stroke_CCC', ...
    participantID);
dirPC1Data = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'Stroke_CCC'],participantID,sess);
dirSrvrC3 = 'W:\Nathan\C3';
dirSrvrData = fullfile(dirSrvrC3,'Data',participantID);
dirSrvrRaw = fullfile(dirSrvrC3,'RawBackupData',participantID,sess);

% define source and destination paths in specified order
srcs = {dirPC1Data dirPC1Profiles ...
    dirPC1Data fullfile(dirPC1ExpGUI,'datlogs')};
dests = {fullfile(dirSrvrData,sess,'PC1') ...
    fullfile(dirSrvrData,'Profiles') fullfile(dirSrvrRaw,'PC1') ...
    fullfile(dirSrvrData,sess,'DataLogsUnsyncd')};

% check if PC1 data directory exists, else raise a warning
if ~isfolder(dirPC1Data)
    error('PC1 data directory does not exist: %s\n',dirPC1Data);
end

% transfer data using utility function with error handling
try
    utils.transferDataSess(srcs,dests,threshTime);  % transfer data
catch ME
    warning(ME.identifier,'Data transfer failed: %s\n',ME.message);
    return;
end

% check if destination directory was created and populated
if ~isfolder(fullfile(dirSrvrData,sess,'PC1'))
    error('Data transfer unsuccessful; destination folder not found.');
end

pathsCreate = {
    fullfile(dirSrvrData,sess,'Figures')
    };

for p = 1:length(pathsCreate)       % for each path to create, ...
    if ~isfolder(pathsCreate{p})    % if does not already exist, ...
        mkdir(pathsCreate{p});      % create it
    end
end

end

