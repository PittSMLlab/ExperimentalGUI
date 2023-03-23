function GenerateNBackSpeedProfileFromPreferred(subjectID, preferredSpeed)
    % subjectID to attach to profile name.
    % preferredSpeed in m/s
    % the function will create and save a new speed profile under 
%     C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\NirsAutomaticityStudy\SubjectID
    %following participant ID and also the latest profile will be named
    %TMNBackProfile under the parent directory NirsAutomaticityStudy
    
    %ramp up and down in 5s. Steady speed walking for 60s then 71.5s with
    %n-back.
    
    strideNum = 100; %60s non task, 60s with N-back
    secToTarget = 3; %ramp up using 0.2m/stride?
    
    %fast
    targetSpeed = preferredSpeed * 1.33;
    velL = [linspace(0, targetSpeed, secToTarget)' ones(100,1)*targetSpeed linspace(targetSpeed, 0, secToTarget)'];
    velR = velL;
    
    %slow
    
    %preferred
    
    %random
    
    
    
end