function status = transferDataSess(srcs, dests, threshTime)
%TRANSFERDATASESS Transfers files between multiple source-destination pairs
%
%   Transfers files from each source in srcs to the corresponding
% destination in dests. Passes threshTime to transferData for each
% pair; transferData copies all files when threshTime is empty.
%
% Inputs:
%   srcs       - cell array of source directory paths
%   dests      - cell array of destination directory paths (same size
%       as srcs)
%   threshTime - datetime (optional); if provided, only files modified
%       after this time are transferred
%
% Outputs:
%   status - logical array indicating successful transfer (1) or
%       failure (0)
%
% Toolbox Dependencies: None
%
% See also TRANSFERDATA.
%
% Example:
%   status = transferDataSess({'src1', 'src2'}, {'dest1', 'dest2'}, ...
%       datetime('now') - days(1));

arguments
    srcs       cell
    dests      cell
    threshTime = []
end

if numel(srcs) ~= numel(dests)
    error('srcs and dests must be cell arrays of the same length.');
end

if ~isempty(threshTime) && ~isa(threshTime, 'datetime')
    error('threshTime must be a datetime object if provided.');
end

status = false(size(srcs));         % success or failure for each transfer

for p = 1:numel(srcs)               % for each source-destination pair, ...
    src  = srcs{p};                 % current source directory
    dest = dests{p};                % corresponding destination directory
    try
        % determine if threshold time should be used based on folder name
        if contains(src,'datlogs')  % if data logs, ...
            fprintf('Transferring recent files from %s to %s\n',src,dest);
            utils.transferData(src,dest,threshTime); % call transfer fxn
        else
            fprintf('Transferring from %s to %s\n',src,dest);
            utils.transferData(src,dest);       % call data transfer fxn
        end
        status(p) = true;           % mark successful if no errors occurred
    catch ME
        warning('Failed to transfer from %s to %s: %s', ...
            src, dest, ME.message);
    end
end

end
