%% Set up GUI and run exp
%load adapation GUI and get handle
handles = guidata(AdaptationGUI);

global profilename

handles.popupmenu2.set('Value',10) %OPEN Loop
profilename = 'C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\NirsAutomaticityStudy\AutomaticityTrials.mat';
manualLoadProfile([],[],handles,profilename)

AdaptationGUI('Execute_button_Callback',handles.Execute_button,[],handles)    