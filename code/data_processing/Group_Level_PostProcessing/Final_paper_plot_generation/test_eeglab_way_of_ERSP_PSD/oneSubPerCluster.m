function STUDY= oneSubPerCluster(STUDY)
%% weighted average across components in each cluster
cluster_lowestIC = STUDY.cluster;
for CL = 3:length(STUDY.cluster)
    rm_comp_ind =[];
    unique_clus_subs = unique(STUDY.cluster(CL).sets);

    for uc = 1:length(unique_clus_subs)
        x = find(STUDY.cluster(CL).sets == unique_clus_subs(uc));
        index = uc;
        if ~isempty(x)
            if size(x,2)>1 %if subject appears more than once in cluster
                rm_comp_ind = [rm_comp_ind, x(2:end)];
            end
        end
    end

    new_outlier_comps = STUDY.cluster(CL).comps(rm_comp_ind);
    new_outlier_sets =  STUDY.cluster(CL).sets(rm_comp_ind);
    cluster_lowestIC(2).comps = [cluster_lowestIC(2).comps, new_outlier_comps]; %CL 2 is outlier comp
    cluster_lowestIC(2).sets = [cluster_lowestIC(2).sets, new_outlier_sets];
    cluster_lowestIC(CL).comps(rm_comp_ind) = [];
    cluster_lowestIC(CL).sets(rm_comp_ind) = [];
end
fprintf('Subject IC ERSPs consolidated to one subject/cluster using lowest IC number:')
fprintf('\n\tSTUDY.cluster_lowestIC')
  STUDY.cluster_og = STUDY.cluster;
  STUDY.cluster_lowestIC = cluster_lowestIC;
  STUDY.cluster =  STUDY.cluster_lowestIC ;
                        
 fprintf('Original cluster saved in STUDY.cluster_og')

end