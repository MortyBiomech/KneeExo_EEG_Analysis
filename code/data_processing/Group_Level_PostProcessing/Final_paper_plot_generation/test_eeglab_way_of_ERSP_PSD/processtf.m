% call newtimef (duplicate function in std_erspplot)
% --------------
function [dataout,erspbase] = processtf(dataSubject, xvals, datatype, singletrials, g)

    % compute ITC or ERSP
    if strcmpi(datatype, 'ersp')
        P = dataSubject .* conj(dataSubject);
        dataout = newtimeftrialbaseln(P, xvals, g);
        % common baseline is removed in std_erspplot
        if strcmpi(singletrials, 'off')
            dataout = squeeze(mean(dataout, 3));
        end
    else
        dataout = dataSubject;
        if strcmpi(singletrials, 'off')
            if ~isfield(g, 'itctype'), g.itctype = 'phasecoher'; end
            if ndims(dataSubject) == 4
                dataSubject = permute(dataSubject, [4 1 2 3]);
                dataout = newtimefitc(dataSubject, g.itctype);
                dataout = permute(dataout, [2 3 1]);
            else
                dataout = newtimefitc(dataSubject, g.itctype);
            end
            dataout = abs(dataout); % required for plotting scalp topo
        end
    end
end