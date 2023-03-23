function [throughput, accs, capacity] = computeThroughput(datalogPath)
    load(datalogPath)
    accs = zeros(1,7)-10; %min value possible is acc = 0, -1*n, min = -6;  initialize to -10 (out of bounds value)
    throughput = zeros(1,7)-10;
    responseTime = zeros(1,7)-10;
    responseTimeSD = zeros(1,7)-10;
    totalHit = 3; %predetermined number
    for n = 0:6
        %col 3 = n, 4= correctness, 5 = numberIndex
        currN = datlog.response.data(:,3) == n;
        response = datlog.response.data(currN,:);
        if ~isempty(response)
            %should respond to each number only once, check for repeat
            [~,ia,~] = unique(response(:,5));
            if length(ia) ~= size(response,1) %there is repeat
                warning(['More than 1 click found for a stimulus. for n = ', num2str(n)])
                response = response(ia,:);
            end
            responseTime(n+1) = mean(response(:,7));
            responseTimeSD(n+1) = std(response(:,7));
            response = response(:,4);
            acc = sum(response)/totalHit;
            if n == 0
                throughput(n+1) = acc;
            else
                throughput(n+1) = (acc - 0.5)/0.5 * n;
            end
            accs(n+1) = acc;
        end
    end
    figure(); subplot(1,3,1);
    plot(0:6,throughput,'LineWidth',2);
    xlabel('n')
    ylabel('Throughput (-n to n)')
    hold on;
    plot(0:6,[1 1:6],'k');
    legend('Participant','Reference');
    xlim([0,6])
    capacity = round(max(throughput));
    
    subplot(1,3,2);
    plot(0:6, accs,'LineWidth',2);
    xlabel('n')
    ylabel('Acc')
    xlim([0,6])
    
    subplot(1,3,3); hold on;
%     plot(0:6, responseTime,'LineWidth',2);
    errorbar(0:6,responseTime,responseTimeSD)
    xlabel('n')
    ylabel('Acc')
    xlim([-0.2,6])
    legend('ResponseT(s) with SD')
end