function adj_p_values_iEMG = stat_analysis(stat_data)

% check normality of group iEMG data
normality_check = zeros(4, 3);
for i = 1:size(stat_data, 1)

    for j = 1:size(stat_data, 2)
        [H, ~, ~] = swtest(stat_data(i, j, :), 0.05);
        normality_check(i, j) = H; 
    end

end



% column1: P1 vs. P3
% column2: P1 vs. P6
% column3: P3 vs. P6
p_values_iEMG = zeros(4, 3);        
          
j_indx = [1, 2;  ...
          1, 3; ...
          2, 3];
for i = 1:size(stat_data, 1)
    
    for j = 1:size(stat_data, 2)

        data1 = squeeze(stat_data(i, j_indx(j, 1), :));
        data2 = squeeze(stat_data(i, j_indx(j, 2), :));
        if normality_check(i, j_indx(j, 1)) == 0 && ...
           normality_check(i, j_indx(j, 2)) == 0
            % check for equal variance
            H = vartest2(data1, data2); % H = 0 equal variances 
            if H == 0
                % Unpaired ttest
                [~, p_values_iEMG(i, j), ~, ~] = ttest2(data1, data2);
            elseif H == 1
                % Unequal variance - Welch's ttest
                [~, p_values_iEMG(i, j), ~, ~] = ...
                    ttest2(data1, data2, 'Vartype','unequal');
            end
        else % if one of the either data1 or data2 cannot pass normality test
            % non-parametric test (Wilcoxon rank-sum test)
            [p_values_iEMG(i, j), ~, ~] = ranksum(data1, data2);
        end

    end

end



%% Apply FDR Correction for multiple comparisons on both tracking errors and
% subjective scores
p_values_iEMG_all = p_values_iEMG(:);  % Flatten the matrix
adj_p = mafdr(p_values_iEMG_all, 'BHFDR', true); % Apply FDR correction
adj_p_values_iEMG = reshape(adj_p, size(p_values_iEMG)); % Reshape back to matrix


end