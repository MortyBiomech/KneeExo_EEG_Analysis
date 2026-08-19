%determine effect size for cluster with lowest p-val
%modified from Arnald Delorme: https://github.com/Donders-Institute/infant-cluster-effectsize/blob/main/do_group_analysis.m
% Input
% data  {} 2x 1 cell, one for each condition , { freq/time x subject}
% X vector of frequencies/time
% 
function [effect] = calc_clust_effectsize(data,x,pval,method)

% [effect] = calc_clust_effectsize({curr_ersp;ref_ersp},alltimes, pval,0);
                 

%determine cluster with lowest p-val
if iscell(pval)
    pval = pval{1,1};
end
p= unique(pval);
p = p(p<0.05);

if isempty(p)
     effect = [];
end

for clusti = 1:length(p)
    
    %3D cluster --ONLY UPDATED METHOD 0 for 3D data, haven't updated Method
    %1 or 2, but possible
    if size(data{1,1},3)>1
       datadim = 3;
       dataDiff = data{1,1}-data{2,1};
       dataDiff = reshape(dataDiff,[],size(dataDiff,3)); % spec diff x sub
       pval = reshape(pval,[],1);
       effectWindow = pval==p(clusti);
       c = dataDiff(effectWindow,:);
    else
    %2D cluster
    datadim = 2;
    effectWindow = find(pval==p(clusti));
   
    %calculate pairwise difference in psd between conditions
    %for each participant
    cond1psd = data{1,1}(effectWindow,:); %[freq x sub]
    cond2psd = data{2,1}(effectWindow,:);
    c = cond2psd-cond1psd;
    end

  


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Option 1: Calculate Cohen's d for the average difference
    % in the respective cluster
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if method == 1
        psd_diff = nanmean(c,1); %avg across freq band
        cohens_d = mean(psd_diff)/std(psd_diff);

        %calculate Cohen's d
        effect(clusti).method = 'avg difference in cluster';
        effect(clusti).SD = std(psd_diff);
        effect(clusti).MEAN = mean(psd_diff);
        effect(clusti).COHENS_D = cohens_d;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Option 2: Determine at maximum effect size and at which channel/time it
    % is maximal (upper bound)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if method ==2
        % Determine maximum effect size avg across subjectse and at which frequency Cohen's d is maximal
        cohens_d = abs(nanmean(c,2)./std(c,0,2));%%abs so doesn't matter if clusters is positive or negative, avg across subjects
        maxcohens_d= max(cohens_d); %
        maxeffectfreq = x(cohens_d == maxdiff);
        effect(clusti).method = 'max effect size';
        effect(clusti).COHENS_D = maxcohens_d;
        effect(clusti).maxeffectfreq=  x(effectWindow(cohens_d == maxcohens_d));
    end


    if method ==0
        cohens_d = abs(nanmean(c,2)./nanstd(c,0,2));%%abs so doesn't matter if clusters is positive or negative, avg across subjects
        maxcohens_d= max(cohens_d); %

        if datadim ==2
        maxeffectfreq = x(effectWindow(cohens_d == maxcohens_d));
        end
        rowi = find(cohens_d==maxcohens_d);
        %calc effect size at freq with max effect
        % computes the mean-difference effect size for a single sample X 
        % against the default mean value of 0. Calc 95% CI using
        % bootstrapping
        e = meanEffectSize(abs(c(rowi,:)),Effect="cohen",ConfidenceIntervalType="bootstrap", ...
            BootstrapOptions=statset(UseParallel=true),NumBootstraps=3000); %if you're having issues with jacknife,  spectral analysis toolbox & Cleanline use Chronux, which has its own jackknife() function.Only one fucntion, den_jack() calls it. Rename it
        
        %calculate and store addiitonal info
        psd_diff = nanmean(c,1); %avg across freq band or timefreq band
      

        effect(clusti).SD = std(psd_diff);
        effect(clusti).MEAN = mean(psd_diff);
        effect(clusti).COHENS_D_avg = mean(psd_diff)/std(psd_diff);
        effect(clusti).COHENS_D_max = e.Effect;
        effect(clusti).CI95 = [e.ConfidenceIntervals];
        if datadim ==2
        effect(clusti).maxeffectfreq =  [maxeffectfreq];
        end
        effect(clusti).window = [x(effectWindow(1)), x(effectWindow(end))];

    end
end
end