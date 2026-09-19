% Manually identified cortical ICs for each subject. The output is used for 
% subsequent clustering, focusing exclusively on cortical ICs and excluding
% ICs categorized as "muscle" or "other."

function cortical_ICs_indentifier(subject_list, ALLEEG, STUDY)

    % 1st column: ICs which were categorized to be Brain by ICLabel and had
    % higher than 50% probability.
    % 2nd column: ICs which need further investigation to check if they are
    % potential Brain ICs or not.
    ICs = cell(length(ALLEEG), 3);
    P_max = cell(length(ALLEEG), 1);

    for i = 1:length(ALLEEG)
        
        P = ALLEEG(i).etc.ic_classification.ICLabel.classifications;
        ICs_RV15 = STUDY.datasetinfo(i).comps;
        P = P(ICs_RV15, :);
        [maxValues, maxIndices] = max(P, [], 2);
        P_max{i, 1} = [maxValues, maxIndices];

        % Maximum Probability is for Brain and P(Brain) is higher than 50%
        x = and(P_max{i, 1}(:, 2) == 1, P_max{i, 1}(:, 1) > 0.5);
        ICs{i, 1} = ICs_RV15(x)';

        %% These ICs need further investigation:
        % Maximum Probability is for Brain but P(Brain) is less than 50%
        p1 = ICs_RV15( and(P_max{i, 1}(:, 2) == 1, P_max{i, 1}(:, 1) <= 0.5) );
        % Maximum Probability is for "Muscle" but P(Muscle) is less than 50%
        p2 = ICs_RV15( and(P_max{i, 1}(:, 2) == 2, P_max{i, 1}(:, 1) <= 0.5) );
        % Maximum Probability is for "Other" but P(Other) is less than 50%
        p3 = ICs_RV15( and(P_max{i, 1}(:, 2) == 7, P_max{i, 1}(:, 1) <= 0.5) );

        ICs{i, 2} = [p1, p2, p3]'; 

    end

    
    %% GUI to select accepted potential Brain ICs
    ic_selection_gui(ALLEEG, ICs, subject_list)
    save(fullfile(pwd, 'Brain_PotentialBrain_AcceptedPotentialBrain.mat'), 'ICs')


end