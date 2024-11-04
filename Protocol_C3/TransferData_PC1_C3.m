% author: ChatGPT (with editing by NWB)
% date (created): 28 Oct. 2024
% purpose: to recursively transfer files and folders to the specified
% destinations, including creating non-existent folders in the destination
% if necessary.
% NOTE: this script assumes that the 'RunProtocol_C3.m' script has just
% been run for the experiment so that the 'participantID' and 'isSession1'
% variables are available in the workspace. retrieve or define them
% manually if this is not the case.
% TODO: update this to be a function since not ideal to reference workspace
% variables (pass as input parameters instead).

if isSession1           % if current session is first walking session, ...
    sess = 'Session1';
else                    % otherwise, ...
    sess = 'Session2';  % session two
end

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

utils.transferDataSess(srcs,dests,threshTime);

pathsCreate = {
    fullfile(dirSrvrData,sess,'Figures')
    fullfile(dirSrvrData,sess,'SyncFiles')
    };

for p = 1:length(pathsCreate)       % for each path to create, ...
    if ~isfolder(pathsCreate{p})    % if does not already exist, ...
        mkdir(pathsCreate{p});      % create it
    end
end

