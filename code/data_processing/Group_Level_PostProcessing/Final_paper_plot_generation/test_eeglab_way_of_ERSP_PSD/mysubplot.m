% mysubplot2 (allow to transpose if necessary)
% -------------------------------------------
function hdl = mysubplot(nr,nc,r,c,subplottype)

    cmargin = 0.2/nc;
    rmargin = 0.2/nr;
    if strcmpi(subplottype, 'transpose') || strcmpi(subplottype, 'on'),   hdl = subplot('position',[(r-1)/nr+rmargin (nc-c)/nc+cmargin 1/nr-2*rmargin 1/nc-2*cmargin]);
    elseif strcmpi(subplottype, 'normal') || strcmpi(subplottype, 'off'), hdl = subplot('position',[(c-1)/nc+cmargin (nr-r)/nr+rmargin 1/nc-2*cmargin 1/nr-2*rmargin]);
    elseif strcmpi(subplottype, 'noplot'), hdl = gca;
    else error('Unknown subplot type');
    end
    
% % mysubplot (allow to transpose if necessary)
% % -------------------------------------------
% function hdl = mysubplot(nr,nc,ind,transp);
% 
%     r = ceil(ind/nc);
%     c = ind -(r-1)*nc;
%     if strcmpi(transp, 'on'), hdl = subplot(nc,nr,(c-1)*nr+r);
%     else                      hdl = subplot(nr,nc,(r-1)*nc+c);
%     end
end