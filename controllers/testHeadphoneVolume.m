%% Set up recording frequency. Read and output input IDs.
Fz = 48000;

%only need to run this once to look up output channel number and check if input 
% evice is connected
info = audiodevinfo;
inputID = nan;
for i = 1:length(info.input)
    if contains(info.input(i).Name, 'Plantronics BT600')
        info.input(i)
        fprintf('Found plantronics input %d \n', info.input(i).ID)
        inputID = info.input(i).ID;
    end
end
fprintf('Input ID is: %d \n', inputID)

%% Play sample audio while recording.
%The recording is needed in case the recording mode changes the audio
%volume
recObj = audiorecorder(Fz, 16, 1, inputID); %Only need to change the last number, the input IDs
[audio_data,audio_fs]=audioread('TestInstructionVolume.mp3');
testInstruction = audioplayer(audio_data,audio_fs);
play(testInstruction);
recordblocking(recObj, 9);
fprintf('Done Testing.\n')
 
%% Stop playing sample audio and check 1)if there is data recorded (modulations in the plot)
% and 2) if the recordings are for 5s
stop(testInstruction);

clc; close all;
recordedData = getaudiodata(recObj);
plot(recordedData);
replay = audioplayer(recordedData, Fz);
recordingDuration = replay.TotalSamples / replay.SampleRate
if (recordingDuration ~= 9)
    disp('The recording is not working. Check the microphone.')
end
% replay = audioplayer(datlog.audioCues.recording{1, 1}, Fz);
% play(replay)
% sound(audioData)
% sound(recordedData, Fz)
% audiowrite('C:\Users\Public\Documents\MATLAB\ExperimentalGUI\datlogs\TestSound.wav', recordedData, Fz)
