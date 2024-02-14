% Adapted from AdaptationGUI > profilebrowse_Callback --- Executes on button press in profilebrowse.
function manualLoadProfile(hObject, eventdata, handles, profileNameStr, velR, velL)
% hObject    handle to profilebrowse (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%           -- these inputs are kept the same as in AdaptationGUI, matlab
%           needs it. 
%profileNameStr:    profile to load
%velR:       vector of right belt speeds. OPTIONAL. if this arg exist, will
%            ignore the profileNameStr
%velL:       vector of left belt speeds. OPTIONA.
try
    if nargin == 4 %if no velL and no velR provided
        load(profileNameStr);
    else
        disp('Skipping profile, loading velL and velR directly')
    end
    
    t = [0:length(velL)-1];
    set(handles.profileaxes,'NextPlot','replace')
    plot(handles.profileaxes,t,velL,'b',t,velR,'r','LineWidth',2);
    if isrow(velL) && isrow(velR)
    set(handles.profileaxes, 'ylim',[min([velL velR])-1,max([velL velR])+1]);
    else
    set(handles.profileaxes, 'ylim',[min([velL;velR])-1,max([velL;velR])+1]);
    end
% ylim([0 2.0]);

xlabel(handles.profileaxes,'Stride Count');
ylabel(handles.profileaxes,'Speed (m/s)');
legend(handles.profileaxes,'Left Foot','Right Foot','AutoUpdate','off');
set(handles.profileaxes,'NextPlot','add')
pause(0.1) %give time for the plot to show up
% 
% set(handles.Status_textbox,'String','Ready');
% set(handles.Status_textbox,'BackgroundColor','Green');
% % set(handles.totalLstepsBox,'String',num2str(length(velL)));
% % set(handles.totalRstepsBox,'String',num2str(length(velL)));
% clear velL velR;
% 
% set(handles.Execute_button,'Enable','on');
catch
    
end
end