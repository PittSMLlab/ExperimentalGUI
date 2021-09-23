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
    if (currentIndex > length (eventorder)) 
        nirsRestEventString = 'LastRest';
    elseif (eventorder(currentIndex) == 0) %next is stand and alphabet
        nirsRestEventString = 'Rest_Before_Stand_And_Alphabet';
    elseif (eventorder(currentIndex) == 1) %next is walk and alphabet
        nirsRestEventString = 'Rest_Before_Walk_And_Alphabet';
    elseif (eventorder(currentIndex) == 2) %next is walk
        nirsRestEventString = 'Rest_Before_Walk';
    end
end