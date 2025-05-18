%% Troubleshoot Bertec Treadmill Force Plates Noise Issue
% author: NWB
% date (created): 10 May 2025
% purpose: to process and analyze all data from the test of treadmill force
% plate noise without running the treadmill belts or stepping on the
% treadmill at all (i.e., just baseline drift).

%% Identify All CSV Files to Process & Analyze
cd(['Z:\Nathan\BertecTreadmillAndForcePlates\' ...
    '20250510_BertecTreadmillForcePlatesTest\Vicon']);
filesCSV = dir('*.csv');            % all CSV files in current directory
numFilesCSV = numel(filesCSV);      % number of CSV files

%% Extract Quality Metrics from CSV Files
% time of the recording from the start of the treadmill in minutes
timeFromTMStartMin = [5 6 187 244 310 367 380 423 481 484];
numNonZeroesPerSecond = nan(2,numFilesCSV);
voltMean = nan(2,numFilesCSV);              % in mV
voltStd = nan(2,numFilesCSV);
conditions = {'Baseline','No Arduino Power','No Scale', ...
    'No Pin 10 Breakout','No Pin 3 Breakout','No Pins 10, 3 Breakout', ...
    'No Pin 60 BNC','No Pin 61 BNC','No Pins 53, 54 BNC', ...
    'With Pins 53, 54, 60, 61 BNCs'};
% column  5: LFz
% column 14: Pin 10
% column 20: RFz
% column 29: Pin 3
for fi = 1:numFilesCSV              % for each CSV file, ...
    nameFile = fullfile(fullfile(filesCSV(fi).folder,filesCSV(fi).name));
    csv = readmatrix(nameFile,'NumHeaderLines',5);
    dur = size(csv,1) / 1000;       % duration in seconds of trial
    numNonZeroesPerSecond(1,fi) = numel(find(csv(:,5))) / dur;
    numNonZeroesPerSecond(2,fi) = numel(find(csv(:,20))) / dur;
    voltMean(1,fi) = mean(csv(:,14),'omitnan').*1000;
    voltMean(2,fi) = mean(csv(:,29),'omitnan').*1000;
    voltStd(1,fi) = std(csv(:,14),'omitnan').*1000;
    voltStd(2,fi) = std(csv(:,29),'omitnan').*1000;

    figure;
    histogram(csv(:,5),'BinEdges',-7.5:0.5:7.5, ...
        'Normalization','probability','EdgeColor','none');
    axis([-7.5 7.5 0 0.25]);
    xlabel('Force (N)','FontSize',16);
    ylabel('Proportion of Samples','FontSize',16);
    title(['LFz - ' conditions(fi)],'FontSize',16);
    saveas(gcf,['Z:\Nathan\BertecTreadmillAndForcePlates\' ...
        '20250517_BertecTreadmillForcePlatesTest\Results\Histograms\' ...
        '20250517_TM_LFz_' erase(conditions{fi},' ') '_Histogram'],'png');
    saveas(gcf,['Z:\Nathan\BertecTreadmillAndForcePlates\' ...
        '20250517_BertecTreadmillForcePlatesTest\Results\Histograms\' ...
        '20250517_TM_LFz_' erase(conditions{fi},' ') '_Histogram'],'fig');

    figure;
    histogram(csv(:,20),'BinEdges',-7.5:0.5:7.5, ...
        'Normalization','probability','EdgeColor','none');
    axis([-7.5 7.5 0 0.25]);
    xlabel('Force (N)','FontSize',16);
    ylabel('Proportion of Samples','FontSize',16);
    title(['RFz - ' conditions(fi)],'FontSize',16);
    saveas(gcf,['Z:\Nathan\BertecTreadmillAndForcePlates\' ...
        '20250517_BertecTreadmillForcePlatesTest\Results\Histograms\' ...
        '20250517_TM_RFz_' erase(conditions{fi},' ') '_Histogram'],'png');
    saveas(gcf,['Z:\Nathan\BertecTreadmillAndForcePlates\' ...
        '20250517_BertecTreadmillForcePlatesTest\Results\Histograms\' ...
        '20250517_TM_RFz_' erase(conditions{fi},' ') '_Histogram'],'fig');
end

%% Plot the Standard Deviation of the Force Plate Signals (in mV) Over Time
c = lines(2);
p1 = polyfit(timeFromTMStartMin,voltStd(1,:),1);
p2 = polyfit(timeFromTMStartMin,voltStd(2,:),1);
x = linspace(min(timeFromTMStartMin),max(timeFromTMStartMin),10);
y1_fit = polyval(p1,x);
y2_fit = polyval(p2,x);
figure;
hold on;
plot(x,y1_fit,'Color',c(1,:),'LineWidth',2);
plot(x,y2_fit,'Color',c(2,:),'LineWidth',2);
plot(timeFromTMStartMin,voltStd(1,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(1,:),'MarkerFaceColor',c(1,:));
plot(timeFromTMStartMin,voltStd(2,:),'^', ...
    'MarkerSize',10,'MarkerEdgeColor',c(2,:),'MarkerFaceColor',c(2,:));
hold off;
axis([0 490 0 1.0]);
xlabel('Time since TM Start (min.)','FontSize',16);
ylabel('Standard Deviation (mV)','FontSize',16);
title('Treadmill Force Plates Standard Deviation','FontSize',18);
legend('LFz','RFz','location','best','box','off');

%% Plot the Standard Deviation of Force Plate Signals (in mV) By Condition
figure;
hold on;
plot(voltStd(1,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(1,:),'MarkerFaceColor',c(1,:));
plot(voltStd(2,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(2,:),'MarkerFaceColor',c(2,:));
hold off;
axis([0 11 0 0.9]);
xticks(1:10);
xticklabels();
xtickangle(30);
ylabel('Standard Deviation (mV)','FontSize',16);
title('Treadmill Force Plates Standard Deviation','FontSize',18);
legend('LFz','RFz','location','best','box','off');

%% Plot the Mean of the Force Plate Signals (in mV) Over Time
p1 = polyfit(timeFromTMStartMin,voltMean(1,:),1);
p2 = polyfit(timeFromTMStartMin,voltMean(2,:),1);
y1_fit = polyval(p1,x);
y2_fit = polyval(p2,x);
eq1_str = sprintf('y_{LFz} = %.3fx + %.3f',p1(1),p1(2));
eq2_str = sprintf('y_{RFz} = %.3fx + %.3f',p2(1),p2(2));
figure;
hold on;
plot(x,y1_fit,'Color',c(1,:),'LineWidth',2);
plot(x,y2_fit,'Color',c(2,:),'LineWidth',2);
plot(timeFromTMStartMin,voltMean(1,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(1,:),'MarkerFaceColor',c(1,:));
plot(timeFromTMStartMin,voltMean(2,:),'^', ...
    'MarkerSize',10,'MarkerEdgeColor',c(2,:),'MarkerFaceColor',c(2,:));
hold off;
axis([0 490 -9 4]);
text(min(x)+5,min(y1_fit)+2,eq1_str, ...
    'VerticalAlignment','bottom','HorizontalAlignment','left');
text(min(x)+5,min(y1_fit)+1,eq2_str, ...
    'VerticalAlignment','bottom','HorizontalAlignment','left');
xlabel('Time since TM Start (min.)','FontSize',16);
ylabel('Mean (mV)','FontSize',16);
title('Treadmill Force Plates Mean','FontSize',18);
legend('LFz','RFz','location','best','box','off');

%% Plot the Mean of the Force Plate Signals (in mV) By Condition
figure;
hold on;
plot(voltMean(1,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(1,:),'MarkerFaceColor',c(1,:));
plot(voltMean(2,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(2,:),'MarkerFaceColor',c(2,:));
hold off;
axis([0 11 ...
    min(voltMean(:)) - 0.1*range(voltMean(:)) ...
    max(voltMean(:)) + 0.1*range(voltMean(:))]);
xticks(1:10);
xticklabels({'Baseline','No Arduino Power','No Scale', ...
    'No Pin 10 Breakout','No Pin 3 Breakout','No Pins 10 & 3 Breakout', ...
    'No Pin 60 BNC','No Pin 61 BNC','No Pins 53 & 54 BNC', ...
    'With Pins 53, 54, 60, & 61 BNCs'});
xtickangle(30);
ylabel('Mean (mV)','FontSize',16);
title('Treadmill Force Plates Mean','FontSize',18);
legend('LFz','RFz','location','best','box','off');

%% Plot the Number of Non-Zero Force Values (in N) Per Second Over Time
figure;
hold on;
plot(timeFromTMStartMin,numNonZeroesPerSecond(2,:),'^', ...
    'MarkerSize',10,'MarkerEdgeColor',c(2,:),'MarkerFaceColor',c(2,:));
plot(timeFromTMStartMin,numNonZeroesPerSecond(1,:),'o', ...
    'MarkerSize',10,'MarkerEdgeColor',c(1,:),'MarkerFaceColor',c(1,:));
hold off;
axis([0 490 -1 55]);
xlabel('Time since TM Start (min.)','FontSize',16);
ylabel('Non-Zero Force Values (N) / Second','FontSize',16);
title('Treadmill Force Plates Non-Zero Force Values','FontSize',18);
legend('RFz','LFz','location','best','box','off');

