%% load datlog
clc
clear

prompt = {'Subject ID:','How many trials were there?:','Is it a fast block? Answer y/n is yes or no respectively'};
dlgtitle = 'fileName';
dims = [1 45];
definput = {'', '',''};
answer = inputdlg(prompt,dlgtitle,dims,definput);

subID = answer{1};
iter = str2num(answer{2});
fast = answer{3};

if fast == 'y' | fast == 'Y' | fast == 'yes' | fast == 'Yes'
    fast = true;
elseif fast == 'n' | fast == 'N' | fast == 'no' | fast == 'No'
    fast = false;
else
    error('You did not specify which type of block is it');
end

if isempty(iter)
    error('You must input number of trials');
end

% profile=['C:\Users\gonza\Desktop\WeberPerception\Prueba\']; %' fileName '.mat'

profile=['C:\Users\Public\Documents\MATLAB\ExperimentalGUI\datlogs\'];

cd(profile);

%% Select the file and summarize the information on the datalog.

for i = 1:iter
    
    [curName,~] = uigetfile;
    load([profile curName],'datlog');
    [aux]=datlogSummarizeTemp(datlog);
    t=table(i*ones(size(aux.date,1),1), [1; zeros(size(aux.date,1)-1,1)],'VariableNames',{'blockNo', 'isFirstInBlock'});  
    aux=cat(2,aux,t);
    
    if i == 1        
        trialData = aux;        
    else        
        trialData = cat(1, trialData, trialData);        
    end    
    
end


writetable(trialData,[profile subID '_interimResults.csv']);

% %% Process each block, generate tables, save as csv
% 
% 
% [trialData]=datlogSummarizeTemp(datlog);
% % rootDir=profile(1:46); %This need to change once I get the location of the datalogs in the lab computer
% writetable(trialData,[profile fileName '.csv']);
    
%% This file assumes the existence of csv files that summarize block results. If this is not the case, run processDatlogs.m

t=readtable([profile subID '_interimResults.csv']);


%% Define quantities of interest

%Adding prev perturbation to table:
t.prevSize=[0;t.pertSize(1:end-1)]; 
t.prevSize(t.isFirstInBlock~=0)=0; %Assigning NaN to previous perturbation for first trial in each block
% trialData.prevFinalSpeed=[0;trialData.lastSpeedDiff(1:end-1)].*[0;diff(trialData.specificID)==0].*[0;diff(trialData.blockNo)==0];

%Creating binary response variable(s):
t.leftResponse=t.initialResponse==-1;
t.rightResponse=t.initialResponse==1;
t.noResponse=isnan(t.initialResponse);
t.nullTrials=t.pertSize==0;
t.correctResponses=t.initialResponse==-sign(t.pertSize) & ~t.nullTrials;
t.incorrectResponses=t.initialResponse==sign(t.pertSize) & ~t.nullTrials;

%Keep original perturbation sizes and then do the Weber Fraction of the
%fast and slow session perturbation sizes
t.copyPertSize = t.pertSize;
t.copyPrevSize = t.prevSize;

if fast
    
    t.pertSize=t.pertSize./1400; 
    t.prevSize=t.prevSize./1400; 
    
else 
    
    t.pertSize=t.pertSize./1050; 
    t.prevSize=t.prevSize./1050;
    
end
    

% % Undesired perturbation sizes, profile mistake or post-processing
% t=t(t.copyPertSize~=75,:); %Marcela to remove the extra probe size
% t=t(t.copyPertSize~=-12,:); %Marcela to remove the extra probe size
% t=t(t.copyPertSize~=13,:);


% Remove null and no response trials (for accurate counting of DOF in stats)
trialData=t; %Here we will remove the non-response trials
trialData=trialData(~trialData.noResponse,:);

%% Logistic fit for slow session 
f1=figure(1);
sSize=40;
[cmap,unsignedMap]=probeColorMap(23);

% %% Figure 1: proportion of left choices as function of Weber Fraction of the slow blocks
% 
% % Get probe sizes
% B=findgroups(trialData.pertSize); %pertSize>0 means vR>vL
% pp=unique(trialData.pertSize); 
% 
% hold on
% set(gca,'Colormap',cmap);
% S=splitapply(@(x) sum(x==-1)/sum(~isnan(x)),trialData.initialResponse,B); %Not counting NR responses
% E=splitapply(@(x) nanstd(x==-1)/sqrt(sum(~isnan(x))),trialData.initialResponse,B); %Not counting NR responses
% ss=scatter(pp,S,sSize,pp,'filled','MarkerEdgeColor','w');
% grid on;
% ylabel('proportion of left choices') 
% axis([-0.300 0.300 0 1]) 
% X=trialData;
% errorbar(pp,S,E,'k','LineStyle','none')
% X.pertSign=sign(X.pertSize);
% 
% set(gca,'Colormap',unsignedMap);
% ll=findobj(gca,'Type','Line');
% set(ll(1:end-1),'Color',.7*ones(1,3));
% uistack(ll(1:end-1),'bottom')
% uistack(ss,'top')
% ylabel('proportion of "left" choices') 
% xlabel('R slower       same        L slower')
% title('Logistic Regression')
% set(gca,'XLim',[-0.300 0.300]) 
% 
% 
% %Add fits:
% frml='leftResponse~pertSize+isFirstInBlock+pertSize:pertSign+prevSize'; %Perhaps we should go right ahead and just do the perturbation size?
% mm0=fitglm(X,frml,'Distribution','binomial','Link','logit')
% %Automated step-down to drop non-sig terms. By default uses a deviance criterion equivalent to LRT test under Wilk's approximation
% mm0=mm0.step('Upper',frml,'Criterion','Deviance','PEnter',0,'PRemove',0.05,'Nsteps',Inf)
% 
% if ~isempty(mm0.Formula.PredictorNames)
%     mm0.plotPartialDependence('pertSize');
%     set(ll,'Color','k','LineWidth',2);
%     f = msgbox({'You may continue the experiment';  ['R-squared: ' num2str(mm0.Rsquared.Ordinary)]; ['R-squared adjusted: ' num2str(mm0.Rsquared.Adjusted)]});
% else
%     warning('STOP EXPERIMENT! There are no significant predictors');
%     f = msgbox({'STOP Experiment! No significant predictors in the model.';  ['R-squared: ' num2str(mm0.Rsquared.Ordinary)]; ['R-squared adjusted: ' num2str(mm0.Rsquared.Adjusted)]}); 
% end
% 
% hold off;

%% Figure 2: proportion of left choices as function of Weber Fraction of the slow blocks

% Get probe sizes
B=findgroups(trialData.pertSize); %pertSize>0 means vR>vL
pp=unique(trialData.pertSize); 

hold on
set(gca,'Colormap',cmap);
S=splitapply(@(x) sum(x==-1)/sum(~isnan(x)),trialData.initialResponse,B); %Not counting NR responses
E=splitapply(@(x) nanstd(x==-1)/sqrt(sum(~isnan(x))),trialData.initialResponse,B); %Not counting NR responses
ss=scatter(pp,S,sSize,pp,'filled','MarkerEdgeColor','w');
grid on;
ylabel('proportion of left choices') 
axis([-0.300 0.300 0 1]) 
X=trialData;
errorbar(pp,S,E,'k','LineStyle','none')
X.pertSign=sign(X.pertSize);

set(gca,'Colormap',unsignedMap);
ll=findobj(gca,'Type','Line');
set(ll(1:end-1),'Color',.7*ones(1,3));
uistack(ll(1:end-1),'bottom')
uistack(ss,'top')
ylabel('proportion of "left" choices') 
xlabel('R slower       same        L slower')
title('Logistic Regression')
set(gca,'XLim',[-0.300 0.300]) 


%Add fits:
frml='leftResponse~pertSize'; %Perhaps we should go right ahead and just do the perturbation size?
mm0=fitglm(X,frml,'Distribution','binomial','Link','logit')
%Automated step-down to drop non-sig terms. By default uses a deviance criterion equivalent to LRT test under Wilk's approximation
% mm0=mm0.step('Upper',frml,'Criterion','Deviance','PEnter',0,'PRemove',0.05,'Nsteps',Inf)

if mm0.Coefficients.pValue(end)<0.05
    mm0.plotPartialDependence('pertSize');
    set(ll,'Color','k','LineWidth',2);
    f = msgbox({'You may continue the experiment';  ['p-value: ' num2str(mm0.Coefficients.pValue(end))]; ['R-squared: ' num2str(mm0.Rsquared.Ordinary)]; ['R-squared adjusted: ' num2str(mm0.Rsquared.Adjusted)]});
else
    warning('STOP EXPERIMENT! Perturbation sign is not a significant predictor');
    f = msgbox({'STOP Experiment! No significant predictors in the model.';  ['p-value: ' num2str(mm0.Coefficients.pValue(end))]; ['R-squared: ' num2str(mm0.Rsquared.Ordinary)]; ['R-squared adjusted: ' num2str(mm0.Rsquared.Adjusted)]}); 
end
