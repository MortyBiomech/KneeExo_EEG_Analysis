function savethisfig(fig,name,figfilepath,type)
if ~exist(figfilepath, 'dir') %check
    mkdir(figfilepath)
end
cd(figfilepath)
if strcmp(type,'fig')
    savefig(fig,name)
else
    saveas(fig,name,type);
end
end