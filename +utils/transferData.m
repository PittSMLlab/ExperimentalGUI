function transferData(src, dest, threshTime)
%TRANSFERDATA Recursively transfer all files and subfolders
%
%   Transfers files from src to dest, optionally filtering by a
% threshold time. Compares file modification times using datenum for
% locale-independent comparison.
%
% Inputs:
%   src        - string or character array; full path to the source
%       directory to be transferred
%   dest       - string or character array; full path to the destination
%       directory where the data is to be transferred
%   threshTime - datetime (optional); only files modified after this
%       time are copied. Pass [] or omit to copy all files.
%
% Outputs:
%   None
%
% Toolbox Dependencies: None
%
% See also TRANSFERDATASESS.
%
% Example:
%   utils.transferData('C:\SourceFolder', 'C:\DestinationFolder', ...
%       datetime('now') - days(1))

arguments
    src        {mustBeTextScalar}
    dest       {mustBeTextScalar}
    threshTime = []
end

if ~isfolder(src)               % if source folder does not exist, ...
    error('Source directory "%s" does not exist.', src);
end

if ~isempty(threshTime) && ~isa(threshTime, 'datetime')
    error('Threshold time must be a ''datetime'' object if provided.');
end

if ~isfolder(dest)              % if destination folder does not exist, ...
    try
        mkdir(dest);            % create it
    catch ME
        error('Failed to create destination directory "%s": %s', ...
            dest, ME.message);
    end
end

srcContents = dir(src);         % list of all files and folders in source

for k = 1:length(srcContents)  % for each item in source directory, ...
    itemName = srcContents(k).name;

    % if current (i.e., working) or parent directory, ...
    if any(strcmp(itemName, {'.', '..'}))
        continue;               % continue to next item (loop iteration)
    end

    srcItem  = fullfile(src, itemName);  % full path of the source item
    destItem = fullfile(dest, itemName); % full path of the destination item

    if srcContents(k).isdir              % if item is a directory, ...
        utils.transferData(srcItem, destItem, threshTime);
    else                                 % otherwise, item is a file
        % if no threshold time or file datenum exceeds threshold, ...
        if isempty(threshTime) || ...
                (srcContents(k).datenum > datenum(threshTime))
            % if item does not exist in destination, ...
            if ~isfile(destItem) % || ~areFilesIdentical(srcItem,destItem)
                try
                    copyfile(srcItem, destItem);
                catch ME
                    warning('Failed to copy file "%s": %s', ...
                        srcItem, ME.message);
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
