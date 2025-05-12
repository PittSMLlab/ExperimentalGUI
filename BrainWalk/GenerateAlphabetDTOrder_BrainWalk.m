%Regenerate the alphabet task order since the previous pseudoranomization
%code was lost. 
% Procedure: 1. the number 1-5 represent: stand alpha A, walk alpha, walk, stand 3 A, walk 3A
% 2. Pregenerate 6 different possible permutations of these 5 tasks (out of
% 5! total possibilities), to make 1) printing datasheet easier, and 2)
% over-randomization with seeds rng(2025). This will be 6 possible trials
% of the task
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
%save it
save('C:\Users\Public\Documents\MATLAB\ExperimentalGUI\BrainWalk\BrainWalk_AlphabetDT_ParticipantOrders','orderForParticipant')
save('W:\BrainWalk\Data\BrainWalk_AlphabetDT_ParticipantOrders','orderForParticipant')
