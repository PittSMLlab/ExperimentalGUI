%Regenerate the alphabet task order since the previous pseudoranomization
%code was lost. 
% Procedure: Used MATLAB R2021a
%1. the number 1-5 represent: stand alpha A, walk alpha, walk, stand 3 A, walk 3A
% 2. Pregenerate 6 different possible permutations of these 5 tasks (out of
% 5! total possibilities), to make 1) printing datasheet easier, and 2)
% avoid over-randomization. Used seeds rng(2025) and picked the first 6 possible
% trials order of the task
% 3. Now generate 200 orders to run these 6 trials. This will be the
% randomization order per subject, with seeds rng(10)
close all; clc
rng(2025)

fprintf('\n Start with A:\n')
possibleTaskOrders = nan(6,5); %1 trial per row
for i = 1:6
    possibleTaskOrders(i,:) = randperm(5); %generate a random permutation of 1:5, e.g., 1 possible order to do the task
    fprintf('%d %d %d %d %d;',possibleTaskOrders(i,:))
end
%save it
save('C:\Users\Public\Documents\MATLAB\ExperimentalGUI\BrainWalk\BrainWalk_AlphabetDT_A_TaskOrders','possibleTaskOrders')
save('W:\BrainWalk\Data\BrainWalk_AlphabetDT_A_TaskOrders','possibleTaskOrders')

%print out the task order in readable string format to make data sheet
taskName = {'stand2A', 'walk2A', 'walk', 'stand3A', 'walk3A'};
taskName(possibleTaskOrders)

%now generate a random order for alphabet B, likely won't use but keep it
%just in case
fprintf('\n Start with B:\n')
possibleTaskOrders = nan(6,5); %1 trial per row
taskVector = [3,6:9]; %for walk, stand alpha B, walk alphaB, stand 3 B, walk 3B
for i = 1:6
    idx = randperm(5); %generate a random permutation of 1:5, e.g., 1 possible order to do the task
    possibleTaskOrders(i,:) = taskVector(idx);
    fprintf('%d %d %d %d %d;',possibleTaskOrders(i,:))
end

%% Now generate the participant order
rng(10); %reset seeds for reproducibility
numParticipant = 200;
orderForParticipant = nan(numParticipant,6); %1 row per participant, and 6 trials per participant ran in randomized order
for i = 1:numParticipant
    orderForParticipant(i,:) = randperm(6); %generate a random permutation of 1:6, i.e., orders to do the preselected trials.
end

%A mistake was made such that BW002 ran the order in row 1, all
%participants following was done correctly (e.g. BW005 would use order in
%row 5, etc.)
%For quick resproducibility purpose, manually shuffle the order for row1
%and row2 so that in analysis this will be correct. 
temp = orderForParticipant(2,:);
orderForParticipant(2,:) = orderForParticipant(1,:);
orderForParticipant(1,:) = temp;

%Another mistake where BW006 ran the incorrect order (did BW005 order for trial1, 
% but experimenter found out and corrected it manullay for the rest withotu repeat, did [2 5 6 4 1 3]
%For reproducibility purpose, manually update it here so that future
%analysis or regeneration of the orders will remain consistent.
orderForParticipant(6,:) = [2 5 6 4 1 3];

%Another error: BW020 ran the order of BW017, the code might have done
%somethign werid that day. Manually fip them now for reproducibility
temp = orderForParticipant(17,:);
orderForParticipant(17,:) = orderForParticipant(20,:);
orderForParticipant(20,:) = temp;

%% save it
save('C:\Users\Public\Documents\MATLAB\ExperimentalGUI\BrainWalk\BrainWalk_AlphabetDT_ParticipantOrders','orderForParticipant')
save('W:\BrainWalk\Data\BrainWalk_AlphabetDT_ParticipantOrders','orderForParticipant')

