function condition_indices = condition_indices_identifier_EMG(data)

    P1 = []; P3 = []; P6 = [];
    for i = 1:length(data)

        if ~strcmp(data{1, i}.Description, 'Experiment')
            continue
        end

        P = data{1, i}.Pressure;
        switch P
            case 1
                P1 = cat(2, P1, i);
            case 3
                P3 = cat(2, P3, i);
            case 6
                P6 = cat(2, P6, i);
        end
        
    end
    
    condition_indices.P1 = P1;
    condition_indices.P3 = P3;
    condition_indices.P6 = P6;
end