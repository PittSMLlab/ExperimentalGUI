%% This script generate the peusudo random order to run the different conditions (conditiosn refer to walk, walk0, stand0 etc.)
% There are 7 conditions (walk, walk0-3, stand0-3) per trial, so a toal of
% 7! ways to randomize orderes of these tasks. To avoid over-randomization,
% and make it easier to print out paper data sheet. Pregenerate 6
% randomization orders (corresponding to 6 trials we plan to run), then all
% participants will use the same 6 randomizations but they will experience
% them in different order.

%% Option1. Generate order for the one with pseudorandom order where within each trial all conditions will be done once (w, s0, ..., w2) in a random orer
close all; clc 
%set seeds for repeatability for Option1. Option2-3 have no random
%component
rng(2025)
%also use names for conditions to improve readability of the code later on,
%even though string comparison is probably slower than integer comparison.
conditions = {'walk','stand0','stand1','stand2','walk0','walk1','walk2'};
trials = 6; totalCond = length(conditions);
pseudoRandomCondOrder = cell(trials,totalCond);
for i = 1:6
    order = randperm(totalCond);
    %put the randomized order in readable format
    pseudoRandomCondOrder(i,:) = conditions(order);
end
%check
condOrder = pseudoRandomCondOrder

%now save this and we will keep using this for all participants
save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-FullPseudoRandom.mat'],'condOrder')

%% Option2. generate one that has first trial easy-hard, then next trial hard to easy, repeat x3
condOrder = {'walk','stand0','walk0','stand1','walk1','stand2','walk2'};
condOrder(2,:) = condOrder(end:-1:1);
condOrder = repmat(condOrder,3,1)
save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-orderedInTrial.mat'],'condOrder')

%% Option3. now generate one that's the same n-level within trial, each cond rep 3 times but walk only repeat 1 time; ordered across trials: trial1=0back, trial2 = 1back, trial3 = 2back, then 2-back, 1back, 0back
%Within trial1: 3 reps of stand0, walk0, and 1 rep of walk; within trial2:
%3 reps of stand1, walk1, and 1 rept of walk, etc.
condOrder = cell(trials,totalCond);
ns = [0:2,2:-1:0]; %easy to hard, then hard to easy
for j = 1: 6
    n = ns(j);
    if mod(j,2) %odd number, start with w
        order = {'walk'};
    else
        order = {};
    end
    if j <=3 %1st half, do standing/ST than walking/DT
        order(end+1:end+2) = {['stand' num2str(n)],['walk' num2str(n)]};
    else
        order(end+1:end+2) = {['walk' num2str(n)],['stand' num2str(n)]};
    end

    for i = 1:2 %repeat two more times
        order(end+1:end+2) = order(end:-1:end-1);
    end

    if ~mod(j,2) %even number, do w in the end
        order{end+1} = 'walk';
    end
    
    condOrder(j,:) = order;
    
    %after permutation, also add in suffix of -rep1, rep2 to separate
    %them
    walkRep = 1; walkNRep = 1; standNRep = 1;
    for i = 1:size(condOrder,2)
        if strcmp(condOrder{j,i},'walk')
            condOrder{j,i} = [condOrder{j,i} '-rep' num2str(walkRep)];
            walkRep = walkRep + 1;
        elseif strcmp(condOrder{j,i},['walk' num2str(n)])
            condOrder{j,i} = [condOrder{j,i} '-rep' num2str(walkNRep)];
            walkNRep = walkNRep + 1;
        elseif strcmp(condOrder{j,i},['stand' num2str(n)])
            condOrder{j,i} = [condOrder{j,i} '-rep' num2str(standNRep)];
            standNRep = standNRep + 1;
        end
    end
end
condOrder

save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-sameWithin_walkRep1_OrderedAcrossTrials012210.mat'],'condOrder')

%% Option4. After discussion with Co-Is. Generate same within trial, but 3 reps of walk, walkn, standn each. Then 2 trials of each n. Ordered from hard-easy,easy-hard
%Trial1 = 2back, trial2 = 1back, trial3=0back, then 0back,1back, and 2back
%Within trial1, 3 reps of walk2, stand2, walk. Then Within trial2, 3 reps
%of walk1, stand1, walk. Etc.
rng(2024); %set seeds for repeatability
conds = {'walk','stand'};
condOrder = {};
for n = 0:2
    conds = {'walk',['walk' num2str(n)],['stand' num2str(n)]};
    conds = repmat(conds,1,3);
    for rep = 1:2 %each n repeat twice to get 6 rep per task total
        condOrder(end+1,:) = conds(randperm(9)); %randomize the orders
        %after permutation, also add in suffix of -rep1, rep2 to separate
        %them
        walkRep = 1; walkNRep = 1; standNRep = 1;
        for i = 1:9
            if strcmp(condOrder{end,i},'walk')
                condOrder{end,i} = [condOrder{end,i} '-rep' num2str(walkRep)];
                walkRep = walkRep + 1;
            elseif strcmp(condOrder{end,i},['walk' num2str(n)])
                condOrder{end,i} = [condOrder{end,i} '-rep' num2str(walkNRep)];
                walkNRep = walkNRep + 1;
            elseif strcmp(condOrder{end,i},['stand' num2str(n)])
                condOrder{end,i} = [condOrder{end,i} '-rep' num2str(standNRep)];
                standNRep = standNRep + 1;
            end
        end
           
    end
end
%now the tasks are in 0,0,1,1,2,2. Reorder them to be hard-easy ,easy-hard
%(2,1,0,0,1,2)
condOrder = condOrder([5 3 1 2 4 6],:);
save(['BrainWalk-n-back-stimulus' filesep 'n-back-condOrder-sameWithinAllRep3_OrderedAcrossTrial210012.mat'],'condOrder')
%% Option 5 Same as Option 4 but generate for 3 back 
rng(2025); %set seeds for repeatability
conds = {'walk','stand'};
condOrder = {};
for n = 0:3 % Go up to 3-back 
    conds = {'walk',['walk' num2str(n)],['stand' num2str(n)]};
    conds = repmat(conds,1,2);
    for rep = 1:2 %each n repeat twice to get 4 rep per task total
        condOrder(end+1,:) = conds(randperm(6)); %randomize the orders
        %after permutation, also add in suffix of -rep1, rep2 to separate
        %them
        walkRep = 1; walkNRep = 1; standNRep = 1;
        for i = 1:6
            if strcmp(condOrder{end,i},'walk')
                condOrder{end,i} = [condOrder{end,i} '-rep' num2str(walkRep)];
                walkRep = walkRep + 1;
            elseif strcmp(condOrder{end,i},['walk' num2str(n)])
                condOrder{end,i} = [condOrder{end,i} '-rep' num2str(walkNRep)];
                walkNRep = walkNRep + 1;
            elseif strcmp(condOrder{end,i},['stand' num2str(n)])
                condOrder{end,i} = [condOrder{end,i} '-rep' num2str(standNRep)];
                standNRep = standNRep + 1;
            end
        end
           
    end
end
%now the tasks are in 0,0,1,1,2,2,3,3. Reorder them to be hard-easy ,easy-hard
%Load the original 2-back 
condOrder2back = load(['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\studies\BrainWalk\BrainWalk-n-back-stimulus' filesep 'n-back-condOrder-sameWithinAllRep2_OrderedAcrossTrial210012.mat']);
%Insert the 3-back on the first and last row of the original 2-back
%condOrder so that it's 3,2,1,0,0,1,2,3
condOrder3back = [condOrder(7,:); condOrder2back.condOrder;  condOrder(8,:)];
save(['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\studies\BrainWalk\BrainWalk-n-back-stimulus' filesep 'n-back-condOrder-sameWithinAllRep2_OrderedAcrossTrial32100123.mat'],'condOrder3back');

%% Option 4.2. Same as option4, but do 2 reps of each task only to save time.
%do it in the same order to save datasheet, just drop the last task
condOrder = load(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-sameWithinAllRep3_OrderedAcrossTrial210012.mat']);
condOrder = condOrder.condOrder;
idxToRemove = nan(size(condOrder)); %boolean array, 0 for keep, 1 for remove
for i = 1:size(condOrder,1) %per row, eliminate everything with rep3
    idxToRemove(i,:) = contains(condOrder(i,:),'-rep3');
end
condOrder = condOrder'; %the logical indexing will flatten the array and put them in column order (top down, then colum2 top-down, etc), what i want to preserve is the orders per row, so first transpose it
condOrder(logical(idxToRemove')) = [];
condOrder = reshape(condOrder,6,6)'; %reshape will put elemetns in each column from top down first, then move to next column, this way i preserve the column order (row transpoted), then transpose back to have the correct elements per row
save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-sameWithinAllRep2_OrderedAcrossTrial210012.mat'],'condOrder')

%% Option4.3. Now generate the randomization orders per participant to do n-backs.
%Within trial will still be 3 reps of walkn,stand, and walk, but the
%isntead of doing 2-back, 1-back, 0-back, 0-1-2back, now do randomized
%order.
sampleSize= 200;
participantTrialOrder = nan(sampleSize, 6);
for i = 1:sampleSize
    participantTrialOrder(i,:) = randperm(6);
end
save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-sameWithinAllRep3_RandomPerSubOrder.mat'],'condOrder')