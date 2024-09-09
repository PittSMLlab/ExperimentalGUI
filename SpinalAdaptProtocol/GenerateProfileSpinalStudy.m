function [profileDir] = GenerateProfileSpinalStudy(slow, fast, baseOnly, profileDir, fastLeg, ramp2Split)
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
        save([profileDir 'CalibrationFast.mat'],'velL' ,'velR')
        
        %calibration slow
        velL = ones(400,1) * slow;
        velR = velL;
        save([profileDir 'CalibrationSlow.mat'],'velL' ,'velR')

    else
        if ramp2Split %20 steps gradual from fast to slow
            ramp2SplitSteps = linspace(fast,slow,20)';
            ramp2SplitStims = zeros(20,1);
        else %if no ramp, give empty to build an abrupt transition.
            ramp2SplitSteps = [];
            ramp2SplitStims = [];
        end
        
        %1st adapt block, default assume left slow
        velL = [repmat(fast,50,1); ramp2SplitSteps; repmat(slow,130,1)];    
        velR = [repmat(fast,50,1); ones(size(ramp2SplitSteps))*fast; repmat(fast,130,1)];
        stimL = [ones(30,1); repmat([0 0 0 1 0 0 0 0 0 0]',2,1); ramp2SplitStims; ones(30,1); repmat([0 0 0 1 0 0 0 0 0 0]',10,1)];
        stimR = stimL;
        
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; %make right go slow
            velL = temp;
        end
        save([profileDir 'Adapt1And5.mat'],'velL' ,'velR','stimL','stimR');
        
        %1st adapt block, default assume left slow
        velL = [repmat(fast,50,1); ramp2SplitSteps; repmat(slow,130,1)];
        velR = [repmat(fast,50,1); ones(size(ramp2SplitSteps))*fast; repmat(fast,130,1)];
        stimL = [[1 1 1 0 0 0 0 0 0 0]'; repmat([0 1 0 0 0 0 0 0 0 0]',4,1); ramp2SplitStims; [1 1 1 0 0 0 0 0 0 0]'; repmat([0 1 0 0 0 0 0 0 0 0]',12,1)];
        stimR = stimL;
        
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; %make right go slow
            velL = temp;
        end
        save([profileDir 'Adapt234.mat'],'velL' ,'velR','stimL','stimR');
        
        %pos short, default right fast.
        velL = [repmat(fast,100,1);repmat(slow,30,1);repmat(fast,20,1)];
        velR = [repmat(fast,100,1);repmat(fast,30,1);repmat(fast,20,1)];
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; %make right go slow
            velL = temp;
        end
        save([profileDir 'PosShort.mat'],'velL' ,'velR')
        
        %neg short, default left fast
        velL = [repmat(fast,50,1);repmat(fast,30,1)];
        velR = [repmat(fast,50,1);repmat(slow,30,1)];
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'NegShort.mat'],'velL' ,'velR')
        
        %generate profile for the split trains, PRE
        rng(100);
        totalTrains = 6; %hard coded for now, always do 6 trains.
%         randTiedSteps = randi([50,60],1,totalTrains - 1);
%         randTiedSteps = randTiedSteps - 10;
        randTiedSteps = [40 45 45 50 40]; %used to be [45    43    44    49    40]
        
        restPadSteps = zeros(50,1); %always pad 50 steps of zero to represent rest.
        ramp2Tied = linspace(0.1*fast,fast,11); %ramp is always 10 strides from 10% (at stride 1) to fast speed (at stride 11)
        ramp2Tied = ramp2Tied(1:end-1)'; %exclude the last in the end so that stride 1-10 are all moving and ramping
        ramp2TiedStim = zeros(size(ramp2Tied));
        
        %built 1st train
        if ramp2Split
            velL = [restPadSteps;ramp2Tied;ones(10,1)*fast; ramp2SplitSteps; ones(20,1)*slow];
            velR = [restPadSteps;ramp2Tied;ones(10,1)*fast; ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
            stimL = [restPadSteps; ramp2TiedStim; ones(10,1); ramp2SplitStims; ones(20,1)];
        else %when no ramp, also fix the 1st tied to be 20 steps instead of 10 (coding error for up to SAH16)
            velL = [restPadSteps;ramp2Tied;ones(20,1)*fast; ramp2SplitSteps; ones(20,1)*slow];
            velR = [restPadSteps;ramp2Tied;ones(20,1)*fast; ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
            stimL = [restPadSteps; ramp2TiedStim; ones(20,1); ramp2SplitStims; ones(20,1)];
        end
        for i = 2:3
            velL = [velL;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast; ramp2SplitSteps; ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast; ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
            stimL = [stimL; restPadSteps; ramp2TiedStim; ones(randTiedSteps(i-1),1); ramp2SplitStims; ones(20,1)];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        stimL = [stimL; restPadSteps];
        stimR = stimL;
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PreSplitTrain_1.mat'],'velL' ,'velR','stimL','stimR');
        
        %2nd train
        velL = [];
        velR = [];
        stimL = [];
        for i = 4:6
            velL = [velL;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast; ramp2SplitSteps; ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast; ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
            stimL = [stimL; restPadSteps; ramp2TiedStim; ones(randTiedSteps(i-1),1); ramp2SplitStims; ones(20,1)];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        stimL = [stimL; restPadSteps];
        stimR = stimL;
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PreSplitTrain_2.mat'],'velL' ,'velR','stimL','stimR');
        
        
        %generate profile for the split trains, POST
%         rng(10); %post use a different rand seeds.
%         randTiedSteps = randi([50,60],1,totalTrains - 1);
%         randTiedSteps = randTiedSteps - 10;
        randTiedSteps = [50 40 50 40 45];%used to be [ 48    40    46    48    45]
        %1st train
        velL = [restPadSteps;ones(45,1)*fast;ramp2SplitSteps; ones(20,1)*slow];
        velR = [restPadSteps;ones(45,1)*fast;ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
        stimL = [restPadSteps; ones(45,1); ramp2SplitStims; ones(20,1)];
        for i = 2:3
            velL = [velL;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast;ramp2SplitSteps; ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast;ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
            stimL = [stimL; restPadSteps; ramp2TiedStim; ones(randTiedSteps(i-1),1); ramp2SplitStims; ones(20,1)];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        stimL = [stimL; restPadSteps];
        stimR = stimL;
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PostSplitTrain_1.mat'],'velL' ,'velR','stimL','stimR');
        
        %2nd train
        velL = [];
        velR = [];
        stimL = [];
        for i = 4:6
            velL = [velL;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast;ramp2SplitSteps;ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp2Tied;ones(randTiedSteps(i-1),1)*fast;ones(size(ramp2SplitSteps))*fast; ones(20,1)*fast];
            stimL = [stimL; restPadSteps; ramp2TiedStim; ones(randTiedSteps(i-1),1); ramp2SplitStims; ones(20,1)];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        stimL = [stimL; restPadSteps];
        
        %2nd train end, then immediately do 100 post-adatp
        velL = [velL; ones(100,1)*fast];
        velR = [velR; ones(100,1)*fast];
        stimL = [stimL; ones(30,1); repmat([0 0 0 1 0 0 0 0 0 0]',7,1)];
        stimR = stimL;
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PostSplitTrain_2.mat'],'velL' ,'velR','stimL','stimR');
        
        %post1, default right fast.
        velL = [repmat(fast,200,1)];
        velR = [repmat(fast,200,1)];
        save([profileDir 'Post1.mat'],'velL' ,'velR')

        %post2, default right fast.
        velL = [repmat(fast,100,1);restPadSteps];
        velR = [repmat(fast,100,1);restPadSteps];
        save([profileDir 'Post2.mat'],'velL' ,'velR')
     
    end %end if-else loop for base vs adapt protocol
end