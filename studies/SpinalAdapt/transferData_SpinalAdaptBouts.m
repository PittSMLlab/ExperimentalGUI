function transferData_SpinalAdaptBouts(participantID, visitNum, threshTime)
%TRANSFERDATA_SPINALADAPTBOUTS Transfer PC1 data for one SpinalAdapt visit.
%
%   Recursively copies one visit's Vicon, NIRS, and data-log files, and
%   the participant's speed profiles (shared by both visits), to the
%   server (W:\Chase\SpinalAdapt\), creating non-existent destination
%   folders as needed, then creates the visit's Results analysis folder.
%   On PC1, each visit's Vicon Nexus and Oxysoft data are in a
%   'Visit01'/'Visit02' folder inside the participant's folder. The
%   server layout (as for SAYA90) is:
%     Data\<participantID>\SpeedProfiles\         (shared by both visits)
%     Data\<participantID>\Visit0N\{Vicon, NIRS, DataLogs, Results}
%     RawBackupData\<participantID>\Visit0N\{Vicon, NIRS, DataLogs}
%   Only files newer than threshTime are copied, so the speed profiles
%   (generated in Visit 1) are transferred once, at the end of Visit 1.
%
% Inputs:
%   participantID - char; participant ID without the visit suffix
%                   (e.g., 'SAYA01', 'SAST01', 'SAMC01')
%   visitNum      - double; visit number, 1 or 2
%   threshTime    - datetime; only files newer than this timestamp are
%                   transferred (typically set at the start of the visit)
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None (calls UTILS.TRANSFERDATASESS in this repository's +utils)
%
% See also RUNPROTOCOL_SPINALADAPTBOUTS, UTILS.TRANSFERDATASESS.

arguments
    participantID (1,:) char
    visitNum      (1,1) double {mustBeMember(visitNum, [1 2])}
    threshTime    (1,1) datetime
end

% TODO: update function to open a GUI for user input if no inputs provided

%% Define Data Paths
visitFolder = sprintf('Visit%02d', visitNum);   % e.g., 'Visit01'
dirExpGUI   = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI';
dirProfiles = fullfile(dirExpGUI, 'profiles', 'SpinalAdaptNirsStudy', ...
    participantID);
dirDatlogs  = fullfile(dirExpGUI, 'datlogs');
dirNIRS     = fullfile(['C:\Users\cntctsml\Documents\Oxysoft Data\' ...
    'SpinalAdaptStudy'], participantID, visitFolder);
dirVicon    = fullfile(['C:\Users\Public\Documents\Vicon Training\' ...
    'SpinalAdaptStudy'], participantID, visitFolder);

dirSrvrSpinalAdapt = 'W:\Chase\SpinalAdapt';
dirSrvrData        = fullfile(dirSrvrSpinalAdapt, 'Data', participantID);
dirSrvrVisit       = fullfile(dirSrvrData, visitFolder);
dirSrvrRawVisit    = fullfile(dirSrvrSpinalAdapt, 'RawBackupData', ...
    participantID, visitFolder);

%% Transfer Files to Server
% Sources and destinations are paired in order; each visit's data is
% transferred to both the primary Data\ and the raw backup
% RawBackupData\ locations. The speed profiles are shared by both visits,
% so they go to the participant's SpeedProfiles\ folder, outside Visit0N.
srcs  = {dirVicon ...
    dirProfiles dirNIRS ...
    dirVicon dirNIRS ...
    dirDatlogs dirDatlogs};
dests = {fullfile(dirSrvrVisit, 'Vicon') ...
    fullfile(dirSrvrData, 'SpeedProfiles') ...
    fullfile(dirSrvrVisit, 'NIRS') ...
    fullfile(dirSrvrRawVisit, 'Vicon') fullfile(dirSrvrRawVisit, 'NIRS') ...
    fullfile(dirSrvrVisit, 'DataLogs') ...
    fullfile(dirSrvrRawVisit, 'DataLogs')};

if ~isfolder(dirVicon)
    error('PC1 Vicon visit directory does not exist: %s\n', dirVicon);
end

try
    utils.transferDataSess(srcs, dests, threshTime);
catch ME
    warning(ME.identifier, 'Data transfer failed: %s\n', ME.message);
    return;
end

if ~isfolder(fullfile(dirSrvrVisit, 'Vicon'))
    error('Data transfer unsuccessful; destination folder not found.');
end

% TODO: update to automatically rename data logs by trial name for C3D2MAT

%% Create Analysis Directories
pathsCreate = {
    fullfile(dirSrvrVisit, 'Results')
    fullfile(dirSrvrVisit, 'WatchData')
    };

for ii = 1:length(pathsCreate)
    if ~isfolder(pathsCreate{ii})
        mkdir(pathsCreate{ii});
    end
end

end
