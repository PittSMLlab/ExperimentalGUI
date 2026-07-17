function muscle = promptHreflexMuscle()
%PROMPTHREFLEXMUSCLE Prompt the experimenter for the H-reflex muscle.
%
%   Asks which muscle to treat as the H-reflex channel for the monitor,
%   defaulting to Soleus (the SpinalAdapt protocol default) but
%   allowing medial or lateral gastrocnemius. Shared by every monitor
%   data source (replay now; a live source in a later phase) so the
%   prompt itself is not duplicated per source.
%
% Inputs:
%   None
%
% Outputs:
%   muscle - char; 'SOL', 'MG', or 'LG'
%
% Toolbox Dependencies:
%   None
%
% See also HREFLEXSOURCEREPLAYC3D, RUNHREFLEXMWAVEMONITOR.

muscleOptions = {'SOL','MG','LG'};
choice = listdlg('ListString',muscleOptions,'SelectionMode','single', ...
    'InitialValue',1,'Name','H-Reflex Muscle', ...
    'PromptString','Select the H-reflex muscle:');
if isempty(choice)
    error('promptHreflexMuscle:noSelection', ...
        'A muscle selection is required.');
end
muscle = muscleOptions{choice};

end
