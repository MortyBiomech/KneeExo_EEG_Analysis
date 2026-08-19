% colorbar for ERSP and scalp plot
% --------------------------------
function cbar_standard(datatype, ng, unitcolor);
    pos = get(gca, 'position');
    tmpc = caxis;
    fact = fastif(ng == 1, 40, 20);
    tmp = axes('position', [ pos(1)+pos(3)+max(pos(3)/fact,0.006) pos(2) max(pos(3)/fact,0.01) pos(4) ]);  
    set(gca, 'unit', 'normalized');
    if strcmpi(datatype, 'itc')
         cbar(tmp, 0, tmpc, 10); ylim([0.5 1]);
         title('ITC','fontsize',10,'fontweight','normal','interpreter','none');
    elseif strcmpi(datatype, 'erpim')
        cbar(tmp, 0, tmpc, 5);
    else
        cbar(tmp, 0, tmpc, 5);
        title(unitcolor);
    end
end