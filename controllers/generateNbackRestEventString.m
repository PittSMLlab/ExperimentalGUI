function nirsRestEventString = generateNbackRestEventString(eventorder, currentIndex)
    %Find out proper rest_before_event string to send to oxysoft tagging an
    %event, this string will be used later in data processing as the
    %baselien to correct for each active task
    %
    % [Input]
    %   - eventorder: cell array of #conditions x 1, represents the order of
    %       conditiosn to run in the current trial. Example eventorder = {'w','s0','s1','s2','w0','w1','w2'}
    %   - currentIndex: integer, representing the current condition
    %       (1-based index)
    % [Output]
    %   - nirsRestEventString: a string that will be sent to OxySoft as
    %       event description/name for the current event. The string is in
    %       format Rest_Before_Task
    %
    % $Author: Shuqi Liu $	$Date: 2025/02/14 10:12:38 $	$Revision: 0.1 $
    % Copyright: Sensorimotor Learning Laboratory 2025
    disp('Generating rest string. CurrentIndex: ')
    disp(currentIndex)
    if (currentIndex > length (eventorder)) 
        nirsRestEventString = 'LastRest';
    else
        nirsRestEventString = ['Rest_Before_' eventorder{currentIndex}];
    end
end