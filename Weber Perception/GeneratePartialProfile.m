%% Run if the Wii controller stopped working
clear all
clc

prompt = {'Copy the directory where new profiles will be located:', 'Is it the first time it happens in this condition? input y/n', 'What stride where they on (choose the smaller number)?'};
dlgtitle = 'fileName';
dims = [1 70];
definput = {'', '', ''};
answer = inputdlg(prompt,dlgtitle,dims,definput);

newFolder = answer{1};
strideNum = str2num(answer{3});
indicator = answer{2};

if indicator == 'y' | indicator == 'Y' | indicator == 'yes' | indicator == 'Yes'
    indicator = true;
elseif indicator == 'n' | indicator == 'N' | indicator == 'no' | indicator == 'No'
    indicator = false;
else
    error('You did not specify which type of block is it');
end


handrail = questdlg('Where is the handrail located in the current session?', ...
    'Handrail Location', ...
    'Front', 'Back','Cancel');

if indicator
    
%     path =  ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\Perception Studies\Weber Perception Faster\' handrail];
    path =  ['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\profiles\Perception Time Window\' handrail];
    
    
else
    
    path =  newFolder;
    
end


% listCond = {'FamiliarizationSlowest', 'FamiliarizationSlow','slowestBlock','mirrorSlowestBlock','slowBlock','mirrorSlowBlock'};

% listCond = {'FamiliarizationSlow', 'FamiliarizationFaster','slowBlock','mirrorSlowBlock','fasterBlock','mirrorFasterBlock'};
listCond = {'Familiarization', 'Block','mirrorBlock'};






[indx,tf] = listdlg('PromptString',{'Which condition you will need to generate the profile from?',...
    ''},...
    'SelectionMode','single','ListString',listCond);

if tf == 1
    
    fileName = [path '\' listCond{indx} '.mat'];
    
    if isfile(fileName)
        
        load(fileName);
        profileNo = 0;
        j=1;
        
    else
        
        tempFiles = {dir(path).name};
        matches = strfind(tempFiles,listCond{indx});
        j = 1;
        for i = 1:length(tempFiles)
            
            if ~isempty(matches{i});
                
                files{j} = tempFiles{i};
                j = j + 1;
                
            end
            
        end
        
        fileName = [path '\' files{end}];
        profileNo = str2num(files{end}(end-4:end-4));
        load(fileName);
        
    end
    
    
    if isnan(velL(strideNum))
        
        firstNoNaN = gt(find(~isnan(velL)),strideNum);
        k = find(firstNoNaN, 1, 'first');
        nexIndx = find(~isnan(velL));
        newIndx = nexIndx(k); %This is the first no NaN after the stride number we stopped at
        nexIndx = nexIndx - 19; % In order to repeat the last probe that person could no indicate a response
        
        velL = velL(newIndx:end);
        velL = [velL velL(11:32)]; %Repeat the very first probe size
        velR = velR(newIndx:end);
        velR = [velR velR(11:32)]; %Repeat the very first probe size
    else
        
        firstNaN = lt(find(isnan(velL)),strideNum);
        k = find(firstNaN, 1, 'last'); %First no NaN where the trial stopped
        nexIndx = find(isnan(velL)); %This is the first NaN before the stride number we stopped at
        newIndx = nexIndx(k) + 1; %This is the first no NaN before the stride number we stopped at
        newIndx = newIndx - 19; % In order to repeat the last probe that person could no indicate a response
        
        velL = velL(newIndx:end);
        velL = [velL velL(11:32)]; %Repeat the very first probe size
        velR = velR(newIndx:end);
        velR = [velR velR(11:32)]; %Repeat the very first probe size
        
    end
    
    
     save([newFolder '\' listCond{indx} num2str(j) '.mat'],'velL','velR');    
     
    
end









    

    


