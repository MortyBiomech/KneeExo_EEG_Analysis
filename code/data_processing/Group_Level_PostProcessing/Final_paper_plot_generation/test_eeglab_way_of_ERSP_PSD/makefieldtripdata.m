function [newdata, design1, design2, design3] = makefieldtripdata(data, chandim, chanlocs);
    
    newdata = {};
    swapdim = [];
    for i = 1:length(data(:))
    
        newdata{i}.dimord    = 'rpt_chan_freq_time';
        newdata{i}.powspctrmdimord = 'rpt_chan_freq_time';
        switch myndims(data{1})
          case 1, 
            newdata{i}.powspctrm = data{i};
            
          case 2,
            if chandim
                 newdata{i}.powspctrm = transpose(data{i});
            else newdata{i}.powspctrm = reshape(transpose(data{i}), size(data{i},2), 1, size(data{i},1));
            end
            
          case 3,
            if chandim == 2 % chandim can be 1 or 2
                swapdim = [2 1];
            end
            if chandim
                 newdata{i}.powspctrm = permute(data{i}, [3 1 2]);
            else newdata{i}.powspctrm = permute(data{i}, [3 4 1 2]); % 4 is a singleton dimension
            end
            
          case 4,
            newdata{i}.powspctrm = permute(data{i}, [4 3 1 2 ]); % Fixed dimension from [4 1 2 3]
        end
        
        newdata{i}.label     = cell(1,size(newdata{i}.powspctrm,2));
        newdata{i}.label(:)  = { 'cz' };
        for ic = 1:length(newdata{i}.label)
            newdata{i}.label{ic} = [ 'c' num2str(ic) ];
        end
        newdata{i}.freq      = [1:size(newdata{i}.powspctrm,3)];
        newdata{i}.time      = [1:size(newdata{i}.powspctrm,4)];
        
        % below in case channels are specified
        % not that statistics are done on time x frequencies or channels
        % so time x frequency x channels do not work yet here
        if ~isempty(chanlocs)
            newdata{i}.powspctrm = squeeze(newdata{i}.powspctrm);
            newdata{i}.label     = { chanlocs.labels };
            newdata{i}.freq      = 1;
            newdata{i}.time      = 1;
        end
        if isempty(chanlocs) && size(newdata{i}.powspctrm,2) ~= 1
            newdata{i}.dimord    = 'rpt_freq_time';
            newdata{i}.powspctrmdimord = 'rpt_freq_time';
        end
    end
    
    design1 = [];
    design2 = [];
    design3 = [];
    for i = 1:size(data,2)
        for j = 1:size(data,1)
            nrepeat = size(data{i}, ndims(data{i}));
            ij = j+(i-1)*size(data,1);
            design1 = [ design1 ones(1, nrepeat)*i ];
            design2 = [ design2 ones(1, nrepeat)*j ];
            design3 = [ design3 [1:nrepeat] ];
        end
    end
        
end