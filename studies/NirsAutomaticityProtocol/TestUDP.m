%%
startmsg = ['<?xml version="1.0" encoding="UTF-8" standalone="no" ?><CaptureStart><Name VALUE="Trial0' num2str(TrialNum,2) '"/><Notes VALUE=""/><Description VALUE=""/><DatabasePath VALUE="' sessionpath '\"/><Delay VALUE="0"/><PacketID VALUE="' num2str(TrialNum) '"/></CaptureStart>'];
startmsg = native2unicode(startmsg,'UTF-8');
myudp = dsp.UDPSender('RemoteIPAddress','255.255.255.255','RemoteIPPort',30,'LocalIPPortSource','Property','LocalIPPort',31);
%send udp start packet
step(myudp,int8(startmsg));
pathflag = 0;

%%
stopmsg=['<?xml version="1.0" encoding="UTF-8" standalone="no" ?><CaptureStop RESULT="SUCCESS"><Name VALUE="Trial' num2str(TrialNum) '"/><DatabasePath VALUE="' nexuspath '\"/><Delay VALUE="0"/><PacketID VALUE="' num2str(TrialNum*10) '"/></CaptureStop>']; %311
step(myudp,int8(stopmsg));