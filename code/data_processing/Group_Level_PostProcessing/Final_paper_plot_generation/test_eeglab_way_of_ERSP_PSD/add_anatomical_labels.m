%% add anatomical labels
function STUDY = add_anatomical_labels(STUDY, eeglabpath)
% global eeglabpath
x = 0;
STUDY.etc.centroids =[];
for i= 3:length(STUDY.cluster)
    x = x+1;
    [STUDY.etc.centroids(x).posxyz]= STUDY.cluster(i).dipole.posxyz;
    [STUDY.etc.centroids(x).momxyz]= STUDY.cluster(i).dipole.momxyz;
    [STUDY.etc.centroids(x).rv]= STUDY.cluster(i).dipole.rv;
end
ft_defaults;

folderList = dir([eeglabpath,'\plugins']);
fieldtripidx = contains({folderList.name},'Fieldtrip');
if ~any(fieldtripidx)
    error('You do not have the fieldtrip plugin installed in EEGLAB')
    return;
end
ftpath = [eeglabpath,'\plugins\',folderList(fieldtripidx).name];
atlas = ft_read_atlas([ftpath,'\template\atlas\aal\ROI_MNI_V4.nii']);
Dipfit_roi = reshape([STUDY.etc.centroids.posxyz],3,[])';

for i = 1:size(Dipfit_roi,1)
    try
        cfg              = [];
        cfg.roi        = Dipfit_roi(i,:);
        cfg.output     = 'multiple';
        cfg.atlas      = atlas;
        cfg.inputcoord = 'mni';
        cfg.sphere = 1;
        labels = ft_volumelookup(cfg, atlas);
        [~, indx] = max(labels.count);
         Atlas_name{i,1} = ['CLs ',num2str(i+2)];
        Atlas_name{i,2} = labels.name(indx);
    end
end

fprintf('Cluster \t\t Label\n');
fprintf('________________________\n');
for i = 1:size(Dipfit_roi,1)
label = cellstr(Atlas_name{i,2});
cl =  cellstr(Atlas_name{i,1});
fprintf('%s\t\t%s\n',cl{:},label{:})
STUDY.cluster(i+2).label = cellstr(Atlas_name{i,2});
end

STUDY.etc.atlas_labels = Atlas_name;
end
