function [W, terms] = lmm21_derive_terms(W, L)
%LMM21_DERIVE_TERMS  The mediation model's derived predictors, on these rows.
%
%   [W, TERMS] = LMM21_DERIVE_TERMS(W, L) adds to W the columns the mediation
%   model in RUN_RESULTS_BEHAVIOUR builds, and returns the names of the ones
%   that survived:
%
%     <mediator>_w   within participant, the value minus that participant's
%                    mean over these rows
%     <mediator>_b   between participant, that participant's mean, then grand
%                    centred over participants
%     Trial_z        trial number, z scored over these rows
%
%   The mediation calls these M1w, M1b, M2w, M2b and Tz, with M1 the effort
%   index and M2 the tracking error. The names here spell the variable out
%   instead, but the quantities are identical.
%
%   TERMS is a struct with fields within, between and trial, each a cell array
%   of the column names that can actually go in a formula. A between term with
%   no variance is left out of TERMS rather than added and left to make the
%   design matrix rank deficient. That is not hypothetical: the effort index is
%   normalised within participant by BUILD_BEHAVIOUR_TABLE, so every
%   participant's mean is four by construction and EffortIndex_b is a column of
%   zeros. The mediation checks for this too, at its betweenTerms loop.
%
%   WHY THE SPLIT. The model carries a by-participant random intercept and no
%   random slope, so a raw trial-level covariate conflates the within
%   participant relationship with the between participant one, and the two can
%   differ in size or even in sign. Separating them lets the within term mean
%   what the sentence in the Results says it means.
%
%   WHY ON THESE ROWS. Each feature is observed on its own subset of trials,
%   so this is called after subsetting. A within term centred on rows the model
%   never sees is not centred on the data it is fitted to, and keeps a between
%   participant residue, which is the thing the split exists to remove.
%
%   One consequence to state in the Methods: the effort index has no between
%   participant variance by construction, so this model cannot ask whether
%   people who work harder overall feel the task as harder. Without a maximum
%   voluntary contraction there is no scale on which it could.
%
%   See also FIT_LMM21_MODELS, RUN_RESULTS_BEHAVIOUR.
%
%   Part of the KneeExo-EEG analysis code.

subjectVar = L.model.subject;
subj = W.(subjectVar);

terms = struct('within', {{}}, 'between', {{}}, 'trial', {{}});

for k = 1:numel(L.model.mediators)

    v  = L.model.mediators{k};
    wn = [v '_w'];
    bn = [v '_b'];

    x = double(W.(v));
    within  = nan(size(x));
    between = nan(size(x));

    [gid, ~] = findgroups(subj);
    for g = 1:max(gid)
        sel = (gid == g);
        mu = mean(x(sel), 'omitnan');
        within(sel)  = x(sel) - mu;
        between(sel) = mu;
    end

    % Grand centre the between term over participants, not over rows, so a
    % participant with more trials does not pull the centre.
    subjectMeans = splitapply(@(v2) v2(1), between, gid);
    between = between - mean(subjectMeans, 'omitnan');

    W.(wn) = within;
    W.(bn) = between;

    terms.within{end+1} = wn;

    % std(x, 'omitnan') is not portable: it needs the weight argument in
    % older MATLAB and is rejected outright by Octave. Drop the non-finite
    % entries explicitly instead.
    sm = subjectMeans(isfinite(subjectMeans));
    if numel(sm) > 1 && std(sm) > 1e-10
        terms.between{end+1} = bn;
    end
end

if ~isempty(L.model.trial) && ismember(L.model.trial, W.Properties.VariableNames)
    t  = double(W.(L.model.trial));
    tf = t(isfinite(t));
    s  = 0;
    if numel(tf) > 1
        s = std(tf);
    end
    if s > 0
        W.Trial_z = (t - mean(t, 'omitnan')) / s;
        terms.trial = {'Trial_z'};
    else
        W.Trial_z = zeros(size(t));
    end
end

end