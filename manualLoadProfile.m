function manualLoadProfile(hObject, eventdata, handles, profileNameStr, velR, velL)
%MANUALLOADPROFILE Load and plot a treadmill speed profile in the GUI axes.
%
%   Adapted from AdaptationGUI > profilebrowse_Callback. When velR and
%   velL are not supplied, loads them from the .mat file named by
%   profileNameStr. Plots both belts on handles.profileaxes.
%
% Inputs:
%   hObject        - handle to the GUI object (required by GUIDE)
%   eventdata      - reserved for future MATLAB versions (required by GUIDE)
%   handles        - GUI handles struct (required by GUIDE)
%   profileNameStr - path to a .mat file containing velL and velR
%   velR           - right-belt speed vector (mm/s); optional, overrides
%                    profileNameStr when provided
%   velL           - left-belt speed vector (mm/s); optional, overrides
%                    profileNameStr when provided
%
% Outputs:
%   None
%
% Toolbox Dependencies:
%   None
%
% See also ADAPTATIONGUI.

try
    if nargin == 4 % if no velL and no velR provided
        load(profileNameStr, 'velL', 'velR');
    else
        disp('Skipping profile, loading velL and velR directly');
    end

    t = 0:length(velL) - 1;
    set(handles.profileaxes, 'NextPlot', 'replace');
    plot(handles.profileaxes, t, velL, 'b', t, velR, 'r', 'LineWidth', 2);
    if isrow(velL) && isrow(velR)
        set(handles.profileaxes, 'ylim', ...
            [min([velL velR]) - 1, max([velL velR]) + 1]);
    else
        set(handles.profileaxes, 'ylim', ...
            [min([velL; velR]) - 1, max([velL; velR]) + 1]);
    end
    % ylim([0 2.0]);
    % set(handles.Status_textbox, 'String', 'Ready');
    % set(handles.Status_textbox, 'BackgroundColor', 'Green');
    % set(handles.totalLstepsBox, 'String', num2str(length(velL)));
    % set(handles.totalRstepsBox, 'String', num2str(length(velL)));
    % clear velL velR;
    % set(handles.Execute_button, 'Enable', 'on');
    xlabel(handles.profileaxes, 'Stride Count');
    ylabel(handles.profileaxes, 'Speed (m/s)');
    legend(handles.profileaxes, 'Left Foot', 'Right Foot', ...
        'AutoUpdate', 'off');
    set(handles.profileaxes, 'NextPlot', 'add');
    pause(0.1); % give time for the plot to show up
catch ME
    warning('manualLoadProfile:loadFailed', '%s', ME.message);
end

end
