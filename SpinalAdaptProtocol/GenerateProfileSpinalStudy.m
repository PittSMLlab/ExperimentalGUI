function [profileDir] = GenerateProfileSpinalStudy(slow, fast, baseOnly, profileDir, fastLeg)
%take info from the nirsTrainInfo to generate profiles for other conditions
%(non-train) in the protocol and save them
%Input:
%   slow, fast: doubles representing speeds 
%   baseOnly: boolean, generate profile for baseline only, true for 1st
%           section of the experiment (fast/slow leg not decided yet). If
%           false, will generate the main exp speeds (without the baseline
%           again)
%   profDir: string, path to save the profiles to.
%   fastLeg: string, 'R' or 'L'. OPTIONAL, if baseonly = true, this doesn't
%   need to be provided.
%
%Output:
%   profDir: string path of where the profiles are saved

    if ~exist(profileDir)
        mkdir(profileDir) %mk directory if doesn't exist yet.
    end
    
    if baseOnly
        %base fast
        velL = ones(100,1) * fast;
        velR = velL;
        save([profileDir 'TMBaseFast.mat'],'velL' ,'velR')

        %base slow
        velL = ones(75,1) * slow;
        velR = velL;
        save([profileDir 'TMBaseSlow.mat'],'velL' ,'velR')

        %base OG slow
        velL = ones(100,1) * slow;
        velR = velL;
        save([profileDir 'OGBaseSlow.mat'],'velL' ,'velR')

        %base OG fast
        velL = ones(100,1) * fast;
        velR = velL;
        save([profileDir 'OGBaseFast.mat'],'velL' ,'velR')
        
        %calibration fast
        velL = ones(100,1) * fast;
        velR = velL;
        save([profileDir 'CalibrationFast.mat'],'velL' ,'velR')
        
        %calibration slow
        velL = ones(75,1) * slow;
        velR = velL;
        save([profileDir 'CalibrationSlow.mat'],'velL' ,'velR')

    else
        %1st adapt block, default assume left slow
        velL = [repmat(fast,50,1);linspace(fast,slow,20)';repmat(slow,130,1)];
        velR = repmat(fast,200,1);
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; %make right go slow
            velL = temp;
        end
        save([profileDir 'Adapt.mat'],'velL' ,'velR')
      
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
        ramp = linspace(0.1*fast,fast,11); %ramp is always 10 strides from 10% (at stride 1) to fast speed (at stride 11)
        ramp = ramp(1:end-1)'; %exclude the 0 and fast in the end so that stride 1-10 are all moving and ramping
        
        %built 1st train
        velL = [restPadSteps;ramp;ones(10,1)*fast;linspace(fast,slow,20)';ones(20,1)*slow];
        velR = [restPadSteps;ramp;ones(50,1)*fast];
        for i = 2:3
            velL = [velL;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;linspace(fast,slow,20)';ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;ones(40,1)*fast];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PreSplitTrain_1.mat'],'velL' ,'velR')
        
        %2nd train
        velL = [];
        velR = [];
        for i = 4:6
            velL = [velL;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;linspace(fast,slow,20)';ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;ones(40,1)*fast];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PreSplitTrain_2.mat'],'velL' ,'velR')
        
        
        %generate profile for the split trains, POST
%         rng(10); %post use a different rand seeds.
%         randTiedSteps = randi([50,60],1,totalTrains - 1);
%         randTiedSteps = randTiedSteps - 10;
        randTiedSteps = [50 40 50 40 45];%used to be [ 48    40    46    48    45]
        %1st train
        velL = [restPadSteps;ones(45,1)*fast;linspace(fast,slow,20)';ones(20,1)*slow];
        velR = [restPadSteps;ones(45,1)*fast;ones(40,1)*fast];
        for i = 2:3
            velL = [velL;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;linspace(fast,slow,20)';ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;ones(40,1)*fast];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PostSplitTrain_1.mat'],'velL' ,'velR')
        
        %2nd train
        velL = [];
        velR = [];
        for i = 4:6
            velL = [velL;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;linspace(fast,slow,20)';ones(20,1)*slow];
            velR = [velR;restPadSteps;ramp;ones(randTiedSteps(i-1),1)*fast;ones(40,1)*fast];
        end
        velL = [velL; restPadSteps];
        velR = [velR; restPadSteps];
        
        %2nd train end, then immediately do 100 post-adatp
        velL = [velL; ones(100,1)*fast];
        velR = [velR; ones(100,1)*fast];
        
        if strcmp(fastLeg, 'L')%if left is fast, swap legs.
            temp = velR;
            velR = velL; 
            velL = temp;
        end
        save([profileDir 'PostSplitTrain_2.mat'],'velL' ,'velR')
        
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