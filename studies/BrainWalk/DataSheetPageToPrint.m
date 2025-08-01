%Helper function to know what task order to run per participant
%Caveat, BW002 used order for BW001
order = load('BrainWalk_AlphabetDT_ParticipantOrders.mat');
order = order.orderForParticipant;

participantID = input('Input participant ID (number code only, e.g., if BW001, enter 1)');
pageOrder = order(participantID,:);
fprintf('Task order to use in code: %s\n(write it down on the data sheet preparation page and update it in NirsAutomaticityAssessment.m line 10 randomization_order)\n',join(string(pageOrder),','));
pageOrder = [1,2,2+pageOrder];
fprintf('Pages to print (copy to word to print): %s\n',join(string(pageOrder),','));
