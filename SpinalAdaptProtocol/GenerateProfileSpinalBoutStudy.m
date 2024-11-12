function [profileDir] = GenerateProfileSpinalBoutStudy(slow, fast, baseOnly, profileDir, fastLeg, ramp2Split)
%take info from the nirsTrainInfo to generate profiles for other conditions
%(non-train) in the protocol and save them
%Input:
%   - slow, fast: doubles representing speeds 
%   - baseOnly: boolean, generate profile for baseline only, true for 1st
%           section of the experiment (fast/slow leg not decided yet). If
%           false, will generate the main exp speeds (without the baseline
%           again)
%   - profDir: string, path to save the profiles to.
%   - fastLeg: string, 'R' or 'L'. OPTIONAL, if baseonly = true, this doesn't
%           need to be provided.
%   - ramp2Split: boolean, OPTIONAL, default true (gradual 20 strides ramp 2 split). 
%           If baseonly = true, this doens't need to be provided. 
%           if true, will have a ramp to split, false will be abrupt to split.
%
%Output:
%   profDir: string path of where the profiles are saved

    if nargin == 5 %provided fast leg but not ramp2split
        ramp2Split = false;
    end
    if ~exist(profileDir)
        mkdir(profileDir) %mk directory if doesn't exist yet.
    end
    
    if baseOnly
        %base fast
        velL = [ones(150,1) * fast];
        velR = velL;
%         stimL = repmat([0 0 0 1 0 0 0 0 0 0]',15,1);
%         stimR = stimL;
        save([profileDir 'TMBaseFast.mat'],'velL' ,'velR')

        %base slow
        velL = [ones(150,1) * slow];
        velR = velL;
%         stimL = repmat([0 0 0 1 0 0 0 0 0 0]',15,1);
%         stimR = stimL;
        save([profileDir 'TMBaseSlow.mat'],'velL' ,'velR')

        %base OG slow
        velL = [ones(100,1) * slow];
        velR = velL;
%         stimL = repmat([0 0 0 1 0 0 0 0 1 0]',10,1);
%         stimR = stimL;
        save([profileDir 'OGBaseSlow.mat'],'velL' ,'velR')

        %base OG fast
        velL = [ones(100,1) * fast];
        velR = velL;
%         stimL = repmat([0 0 0 1 0 0 0 0 1 0]',10,1);
%         stimR = stimL;
        save([profileDir 'OGBaseFast.mat'],'velL' ,'velR')
        
        %calibration fast
        velL = ones(400,1) * fast;
        velR = velL;
        stimSteps = [0 2 2 2 2, repmat([6 2 2 2 2],1,6) repmat([6 2 2], 1,5)]; %build the intervals, 1st time a new stim intensity needs to be set, give a 6 stride break to turn the knobs
        stimSteps = 5+cumsum(stimSteps); %first 5 stride no stim, give participant time to settle in
        stimL = zeros(400,1);
        stimL(stimSteps) = 1;
        stimR = stimL;
        save([profileDir 'CalibrationFast.mat'],'velL' ,'velR','stimL','stimR')
        
        %calibration slow
        velL = ones(400,1) * slow;
        velR = velL;
        save([profileDir 'CalibrationSlow.mat'],'velL' ,'velR','stimL','stimR')

    else
        if ramp2Split %20 steps gradual from fast to slow
            ramp2SplitSteps = linspace(fast,slow,20)';
            ramp2SplitStims = zeros(20,1);
        else %if no ramp, give empty to build an abrupt transition.
            ramp2SplitSteps = [];
            ramp2SplitStims = [];
        end
                
        rng(100);
        repPerTrain = 4; %hard coded for now, always do 6 trains.
        totalSplitTrains = 5; 
        totalCtrTrains = 2;
        randTiedStepsSplit = randi([50,60],totalSplitTrains, repPerTrain);
        randTiedStepsSplit(1,1) = 20; %hard-code, first train first tied to 20
        randTiedStepsCtr = randi([50,60],totalCtrTrains, repPerTrain);
        
        restPadSteps = zeros(50,1); %always pad 50 steps of zero to represent rest.
        ramp2Tied = linspace(0.1*fast,fast,11); %ramp is always 10 strides from 10% (at stride 1) to fast speed (at stride 11)
        ramp2Tied = ramp2Tied(1:end-1)'; %exclude the last in the end so that stride 1-10 are all moving and ramping
        ramp2TiedStim = zeros(size(ramp2Tied));

        %build control train (always tied walking)
        for ctTrain = 1:totalCtrTrains
            velL = [];  stimL = []; %initialize to empty
            for i = 1:repPerTrain
                velL = [velL;restPadSteps;ramp2Tied;ones(randTiedStepsCtr(ctTrain,i),1)*fast; ramp2SplitSteps; ones(20,1)*slow]; %default left slow
                stimL = [stimL; restPadSteps; ramp2TiedStim; ones(randTiedStepsCtr(ctTrain,i),1); ramp2SplitStims; ones(20,1)];
            end
            velL = [velL; restPadSteps];
            stimL = [stimL; restPadSteps];
            velR = velL;
            stimR = stimL;

            save([profileDir 'CtrlTrain_' mat2str(ctTrain) '.mat'],'velL','velR','stimL','stimR');
        end
        
        %build split trains
        for splitTrain = 1:totalSplitTrains
            velL = [];  velR = []; stimL = []; %initialize to empty
            for i = 1:repPerTrain
                velL = [velL;restPadSteps;ramp2Tied;ones(randTiedStepsSplit(splitTrain,i),1)*fast; ramp2SplitSteps; ones(20,1)*slow]; %default left slow
                velR = [velR;restPadSteps;ramp2Tied;ones(randTiedStepsSplit(splitTrain,i),1)*fast; ramp2SplitSteps; ones(20,1)*fast]; 
                
                stimL = [stimL; restPadSteps; ramp2TiedStim; ones(randTiedStepsSplit(splitTrain,i),1); ramp2SplitStims; ones(20,1)];
            end
            velL = [velL; restPadSteps];
            velR = [velR; restPadSteps];
            stimL = [stimL; restPadSteps];
            
            if splitTrain == totalSplitTrains %last split train (add 100 post-adapt)
                velL = [velL; ones(150,1)*fast];
                velR = [velR; ones(150,1)*fast];
                stimL = [stimL; repmat([1 0 0 0 0],1,30)]; %every 5 stimulate
            end
            
            stimR = stimL;
            
            if strcmp(fastLeg, 'L') %if left is fast, swap legs.
                temp = velR;
                velR = velL; 
                velL = temp;
            end
            save([profileDir 'PreSplitTrain_' num2str(splitTrain) '.mat'],'velL' ,'velR','stimL','stimR');
        end
        
        %post1, default right fast (so neg short is left fast), and with a neg short in between
        velR = [repmat(fast,50,1); ones(slow, 30, 1); ones(100,1) * fast];
        velL = [repmat(fast,50,1); ones(fast, 30, 1); ones(100,1) * fast];
        if strcmp(fastLeg, 'L') %if left is fast in regular intervals, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'Post1.mat'],'velL' ,'velR')

        %post2, default right fast.
        velL = [repmat(fast,200,1);restPadSteps];
        velR = [repmat(fast,200,1);restPadSteps];
        save([profileDir 'Post2.mat'],'velL' ,'velR')
     
    end %end if-else loop for base vs adapt protocol
end