function nirsRestEventString = generateNirsRestEventString(eventorder, currentIndex)
    % eventAudioKey: the internal string used to locate audio mp3, or empty
    % if no audio need to be displayed for this event (i.e. trial end)
    %
    % eventIdNirs: the single letter id of the event used to log event in
    % the Oxysoft
    %
    % eventDisplayString: a nicer display string used to print and log in
    % nirs (includign the strating alphabet letter
    %
    % instructions: the map of audioplayer object keyed by the audio key
    % string
    %
    % datlog: the data log struct, used to track start time
    %
    % Oxysoft: the Oxysoft object, to remote connect and log events.
    %
    % nirsPresent: boolean indicating if testing with the instrument
    % Oxysoft present and connected or nos
    %
    %1 = stand and alphabet A, 2 = walk and alphabet A, 3 = walk, 4 = stand and
    %alphabet 3 A, 5 = walk and alphabet 3 A; 6 = stand and alphabet B, 7 = walk and alphabet B, 8 = stand and
    %alphabet 3B, 9 = walk and alphabet 3B
    disp('Generating rest string. CurrentIndex: ')
    disp(currentIndex)
    if (currentIndex > length (eventorder)) 
        nirsRestEventString = 'LastRest';
    elseif (eventorder(currentIndex) == 1) %next is stand and alphabet
        nirsRestEventString = 'Rest_Before_Stand_And_Alphabet_A';
    elseif (eventorder(currentIndex) == 2) %next is walk and alphabet
        nirsRestEventString = 'Rest_Before_Walk_And_Alphabet_A';
    elseif (eventorder(currentIndex) == 3) %next is walk
        nirsRestEventString = 'Rest_Before_Walk';
    elseif (eventorder(currentIndex) == 4) 
        nirsRestEventString = 'Rest_Before_Stand_And_Alphabet_3A';
    elseif (eventorder(currentIndex) == 5) 
        nirsRestEventString = 'Rest_Before_Walk_And_Alphabet_3A';
    elseif (eventorder(currentIndex) == 6) 
        nirsRestEventString = 'Rest_Before_Stand_And_Alphabet_B';
    elseif (eventorder(currentIndex) == 7) 
        nirsRestEventString = 'Rest_Before_Walk_And_Alphabet_B';
    elseif (eventorder(currentIndex) == 8) 
        nirsRestEventString = 'Rest_Before_Stand_And_Alphabet_3B';
    elseif (eventorder(currentIndex) == 9) 
        nirsRestEventString = 'Rest_Before_Walk_And_Alphabet_3B';
    end
end