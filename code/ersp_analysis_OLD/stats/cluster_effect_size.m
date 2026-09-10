function effect = cluster_effect_size(erspPair, pvalMap, times, freqs, method)
% CLUSTER_EFFECT_SIZE  Cohen's d for each significant time-frequency cluster.
%
%   EFFECT = CLUSTER_EFFECT_SIZE(ERSPPAIR, PVALMAP, TIMES, FREQS)
%   EFFECT = CLUSTER_EFFECT_SIZE(ERSPPAIR, PVALMAP, TIMES, FREQS, METHOD)
%
%   ERSPPAIR  {2 x 1} cell, {testCondition; referenceCondition}, each
%             [freq x time x subject]. A 2-D pair, [freq x subject], is also
%             accepted for spectra; pass TIMES = [] then.
%   PVALMAP   cluster p-value map from the permutation test, same
%             [freq x time] size as one subject's ERSP. Every pixel of a
%             cluster carries that cluster's p-value, which is how the
%             clusters are told apart here.
%   TIMES     time axis, one value per column of PVALMAP; [] for 2-D input
%   FREQS     frequency axis, one value per row of PVALMAP
%   METHOD    0 (default) peak Cohen's d over the cluster, with a bootstrap
%               95% CI
%             1 Cohen's d of the cluster-average difference
%             2 peak Cohen's d, no CI
%
%   EFFECT    struct array, one element per cluster with p < 0.05, or []
%             .COHENS_D_max  effect size at the peak pixel
%             .COHENS_D_avg  effect size of the cluster average
%             .CI95          bootstrap CI on COHENS_D_max (method 0 only)
%             .timeWindow    [first last] time spanned by the cluster
%             .freqWindow    [low high] frequency spanned by the cluster
%             .peakTime, .peakFreq  location of the peak pixel
%
% Adapted from Arnaud Delorme,
% https://github.com/Donders-Institute/infant-cluster-effectsize
%
% Changes from the original (calc_clust_effectsize)
% -------------------------------------------------
%   * The reported window was wrong for 3-D (time-frequency) input, the only
%     kind this analysis uses. The original indexed the axis vector with a
%     LOGICAL mask element, x(effectWindow(1)) -- a logical scalar, so it
%     returned x(1) whenever the first pixel was in the cluster and errored
%     or returned empty otherwise. It never described the cluster. The
%     cluster extent is now resolved with IND2SUB and reported as a real
%     time window and frequency window, which is why this function now takes
%     both axes instead of one.
%   * METHOD 2 referenced an undefined variable (maxdiff) and would have
%     errored on any call.
%   * EFFECT is preallocated rather than grown inside the loop.
%
% Sign convention, preserved from the original and worth knowing: for 3-D
% input the difference is test minus reference, for 2-D it is reference
% minus test. COHENS_D_max is unaffected (it is an absolute value) but MEAN
% and COHENS_D_avg change sign between the two.

    if nargin < 5 || isempty(method)
        method = 0;
    end
    if iscell(pvalMap)
        pvalMap = pvalMap{1,1};
    end

    clusterP = unique(pvalMap);
    clusterP = clusterP(clusterP < 0.05);

    effect = [];
    if isempty(clusterP)
        return
    end

    isVolume = size(erspPair{1,1}, 3) > 1;
    if isVolume
        [nFreq, nTime, ~] = size(erspPair{1,1});
        assert(isequal(size(pvalMap), [nFreq nTime]), ...
            'cluster_effect_size:SizeMismatch', ...
            'pvalMap is %dx%d but each ERSP is %dx%d.', ...
            size(pvalMap,1), size(pvalMap,2), nFreq, nTime);

        pairDiffAll = erspPair{1,1} - erspPair{2,1};                  % test - ref
        pairDiffAll = reshape(pairDiffAll, [], size(pairDiffAll, 3)); % pixel x sub
        pvalFlat    = pvalMap(:);
    end

    template = struct('method', '', 'SD', [], 'MEAN', [], ...
        'COHENS_D_avg', [], 'COHENS_D_max', [], 'CI95', [], ...
        'timeWindow', [], 'freqWindow', [], 'peakTime', [], 'peakFreq', [], ...
        'nPixels', []);
    effect = repmat(template, 1, numel(clusterP));

    for ci = 1:numel(clusterP)
        if isVolume
            inCluster = pvalFlat == clusterP(ci);
            pairDiff  = pairDiffAll(inCluster, :);
            pixelIdx  = find(inCluster);
        else
            pixelIdx  = find(pvalMap == clusterP(ci));
            pairDiff  = erspPair{2,1}(pixelIdx,:) - erspPair{1,1}(pixelIdx,:);
        end

        % Cohen's d per pixel, across subjects. ABS because a cluster may be
        % a power decrease as readily as an increase.
        cohensD = abs(mean(pairDiff, 2, 'omitnan') ./ ...
                       std(pairDiff, 0, 2, 'omitnan'));
        [maxCohensD, peakPixel] = max(cohensD);

        meanDiff = mean(pairDiff, 1, 'omitnan');   % average over the cluster

        effect(ci).SD           = std(meanDiff);
        effect(ci).MEAN         = mean(meanDiff);
        effect(ci).COHENS_D_avg = mean(meanDiff) / std(meanDiff);
        effect(ci).nPixels      = numel(pixelIdx);

        switch method
            case 1
                effect(ci).method       = 'avg difference in cluster';
                effect(ci).COHENS_D_max = effect(ci).COHENS_D_avg;
            case 2
                effect(ci).method       = 'peak effect size';
                effect(ci).COHENS_D_max = maxCohensD;
            otherwise
                effect(ci).method = 'peak effect size, bootstrap 95% CI';
                e = meanEffectSize(abs(pairDiff(peakPixel,:)), ...
                    Effect = "cohen", ...
                    ConfidenceIntervalType = "bootstrap", ...
                    BootstrapOptions = statset(UseParallel = true), ...
                    NumBootstraps = 3000);
                effect(ci).COHENS_D_max = e.Effect;
                effect(ci).CI95         = e.ConfidenceIntervals;
        end

        if isVolume
            [freqIdx, timeIdx] = ind2sub([nFreq nTime], pixelIdx);
            effect(ci).timeWindow = [times(min(timeIdx)), times(max(timeIdx))];
            effect(ci).freqWindow = [freqs(min(freqIdx)), freqs(max(freqIdx))];
            effect(ci).peakTime   = times(timeIdx(peakPixel));
            effect(ci).peakFreq   = freqs(freqIdx(peakPixel));
        else
            effect(ci).freqWindow = [freqs(min(pixelIdx)), freqs(max(pixelIdx))];
            effect(ci).peakFreq   = freqs(pixelIdx(peakPixel));
        end
    end
end
