function condition_indices = condition_indices_identifier_EMG_ScoreBased(data, subject)
    
    scores = [];
    for j = 1:length(data)
        
        if ~strcmp(data{1, j}.Description, 'Experiment')
            continue
        end

        scores = cat(2, scores, data{1, j}.Score);
        
    end
    scores = scores(scores ~= 0);
    
    
    %% clustering scores with KNN
   
    num_clusters = 3; % Define number of clusters
    
    max_score = max(scores);
    min_score = min(scores);
    initial_centers = [min_score, (min_score + max_score)/2, max_score]';

    if subject == 6
        initial_centers = [1, 4, 9]';
    end

    % Apply k-means clustering per subject
    [idx, C] = kmeans(scores', num_clusters, 'Start', initial_centers);
    
    % Sort cluster centers and get sorted indices
    [~, sorted_indices] = sort(C);
    
    % Assign clusters based on sorted order
    new_idx = zeros(size(idx));
    for j = 1:num_clusters
        new_idx(idx == sorted_indices(j)) = j;
    end
        
    new_idx = new_idx';



    S1 = []; S2 = []; S3 = [];
    for i = 1:length(new_idx)

        S = new_idx(i);
        switch S
            case 1
                S1 = cat(2, S1, i);
            case 2
                S2 = cat(2, S2, i);
            case 3
                S3 = cat(2, S3, i);
        end
        
    end
    
    condition_indices.S1 = S1;
    condition_indices.S2 = S2;
    condition_indices.S3 = S3;
    

end