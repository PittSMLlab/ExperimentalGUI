function status = transferDataSess(srcs,dests,threshTime)
%TRANSFERDATASESS Transfers files between multiple source-destination pairs
%   This function transfers files from each source directory in `srcs` to
% the corresponding destination directory in `dests`, optionally filtering
% by a threshold time for recent files. If the source directory contains
% 'datlogs', only files modified after `threshTime` will be transferred.
%
% Input(s):
%   srcs: cell array of source directory paths (each row is one pair)
%   dests: cell array of destination directory paths (same size as srcs)
%   threshTime: datetime (optional); if provided, only files modified after
%       this time are transferred for directories containing 'datlogs'
%
% Output(s):
%   status: logical array indicating successful transfer (1) or failure (0)
%
% Example:
%   status = transferDataSess({'src1','src2'},{'dest1','dest2'}, ...
%       datetime('now') - days(1));

narginchk(2,3);                     % verify correct number input arguments
% validate inputs
if ~iscell(srcs) || ~iscell(dests) || numel(srcs) ~= numel(dests)
    error(['Inputs `srcs` and `dests` must be cell arrays of the ' ...
        'same length.']);
end

if nargin < 3                       % if no third input, ...
    threshTime = [];                % set to default of empty array
elseif ~isempty(threshTime) && ~isa(threshTime,'datetime')  % validate
    error('`threshTime` must be a `datetime` object if provided.');
end

status = false(size(srcs));         % success or failure for each transfer

for p = 1:numel(srcs)               % for each source-destination pair, ...
    src = srcs{p};                  % current source directory
    dest = dests{p};                % corresponding destination directory
    try
        % determine if threshold time should be used based on folder name
        if contains(src,'datlogs')  % if data logs, ...
            fprintf('Transferring recent files from %s to %s\n',src,dest);
            utils.transferData(src,dest,threshTime);% call transfer fxn
        else
            fprintf('Transferring from %s to %s\n',src,dest);
            utils.transferData(src,dest);   % call data transfer fxn
        end
        status(p) = true;           % Mark successful if no errors occurred
    catch ME
        warning('Failed to transfer from %s to %s: %s',src,dest,ME.message);
    end
end

end

