function STUDY = oneSubPerCluster(STUDY)
% ONESUBPERCLUSTER  Compatibility shim -- use ONE_IC_PER_SUBJECT instead.
%
% Kept because create_stats.m, under
% _NHB/sPCA_denoising_of_TF_data/permutation_based_TF_ROIs, still calls this
% name. ONE_IC_PER_SUBJECT does the same thing and additionally selects the
% lowest IC index explicitly rather than relying on the component list
% happening to be in ascending order.

    STUDY = one_ic_per_subject(STUDY);
end
