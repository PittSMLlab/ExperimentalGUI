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

%% Option3. now generate one that's the same within trial but across trials go from easy to hard, then hard to easy
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
end
condOrder

save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-sameInTrialOrderedAcrossTrials.mat'],'condOrder')

%% Option4. After discussion with Co-Is. Generate same within trial, but 3 reps of walk, walkn, standn each. Then 2 trials of each n.
rng(2024); %set seeds for repeatability
conds = {'walk','stand'};
condOrder = {};
for n = 0:2
    conds = {'walk',['walk' num2str(n)],['stand' num2str(n)]};
    conds = repmat(conds,1,3);
    for rep = 1:2 %each n repeat twice to get 6 rep per task total
        condOrder(end+1,:) = conds(randperm(9)); %randomize the orders
    end
end
save(['BrainGait-n-back-stimulus' filesep 'n-back-condOrder-sameInTrialEachRep2.mat'],'condOrder')

%Now generate the randomization orders per participant to do n-backs.
sampleSize= 200;
participantTrialOrder = nan(sampleSize, 6);
for i = 1:sampleSize
    participantTrialOrder(i,:) = randperm(6);
end
save(['BrainGait-n-back-stimulus' filesep 'n-back-subjectOrder-sameInTrialEachRep2.mat'],'condOrder')



