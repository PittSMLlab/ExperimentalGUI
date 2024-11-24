function transferData(src,dest,threshTime)
%TRANSFERFILES Recursively transfer all files and subfolders
%   This function transfers files from the source directory, 'src', to
% the corresponding destination directory, 'dest', optionally filtering by
% a threshold time for recent files. If the source directory contains
% 'datlogs', only files modified after `threshTime` will be transferred.
%
% input(s):
%   src: string or character array of the full path to the source directory
%       to be transferred
%   dest: string or character array of the full path to the destination
%       directory where the data is to be transferred
%
% Example:
%   utils.transferData('C:\SourceFolder','C:\DestinationFolder', ...
%       datetime('now') - days(1))

narginchk(2,3);                 % verify correct number of input arguments

% validate input paths
if ~isfolder(src)               % if source folder does not exist, ...
    error('Source directory "%s" does not exist.',src);
end

if ~(ischar(dest) || isstring(dest))
    error('Destination directory must be a string or character array.');
end

if nargin < 3                   % if no third 'threshTime' input, ...
    threshTime = [];            % set to empty by default if not provided
elseif ~isempty(threshTime) && ~isa(threshTime,'datetime')
    error('Threshold time must be a ''datetime'' object if provided.');
end

if ~isfolder(dest)              % if destination folder does not exist, ...
    try
        mkdir(dest);            % create it
    catch ME
        error('Failed to create destination directory "%s": %s', ...
            dest,ME.message);
    end
end

srcContents = dir(src);         % list of all files and folders in source

for k = 1:length(srcContents)   % for each item in source directory, ...
    itemName = srcContents(k).name;

    % if current (i.e., working) or parent directory, ...
    if any(strcmp(itemName,{'.','..'}))
        continue;               % continue to next item (loop iteration)
    end

    srcItem = fullfile(src,itemName);   % Full path of the source item
    destItem = fullfile(dest,itemName); % Full path of the destination item

    if srcContents(k).isdir             % if item is a directory, ...
        utils.transferData(srcItem,destItem,threshTime);
    else                                % otherwise, item is a file
        % if no threshold time provided or file time exceeds threshold, ...
        if isempty(threshTime) || (datetime(srcContents(k).date, ...
                'InputFormat','dd-MMM-yyyy HH:mm:ss') > threshTime)
            % if item does not exist in destination, ...
            if ~exist(destItem,'file') % || ...
                % ~areFilesIdentical(srcItem,destItem)
                try
                    copyfile(srcItem,destItem);
                catch ME
                    warning('Failed to copy file "%s": %s', ...
                        srcItem,ME.message);
                end
            end
        end
    end
end

end

% function areIdentical = areFilesIdentical(file1,file2)
% % Compare file sizes and modification dates to check if files are identical
%
% fileInfo1 = dir(file1);
% fileInfo2 = dir(file2);
% areIdentical = (fileInfo1.bytes == fileInfo2.bytes) && ...
%     (fileInfo1.datenum == fileInfo2.datenum);
%
% end

