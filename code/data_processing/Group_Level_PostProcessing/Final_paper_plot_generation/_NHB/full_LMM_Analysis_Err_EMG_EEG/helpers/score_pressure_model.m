function [T_clean, lme_cat] = score_pressure_model(tbl)

    %% Layered NHB-style figure: Score vs Pressure
    % Layers (back → front):
    % 1) Violin plots (blue / orange / red, FaceAlpha = 0.5)
    % 2) Subject mean scores (white circles, dark edges)
    % 3) Subject trajectories (thin grey lines)
    % 4) LMM marginal means ± 95% CI (black)
    
    % Assumes table tbl with:
    %   tbl.Score
    %   tbl.Pressure_cat  (categorical: '1','3','6')
    %   tbl.Subject_cat   (categorical)
    
    
    
    tbl_plot = tbl;  % work on a copy
        
    isBad = isnan(tbl_plot.Score) | ~isfinite(tbl_plot.Score) | ...
            (tbl_plot.Score < 1) | (tbl_plot.Score > 10);
    
    nBad = nnz(isBad);
    nTot = height(tbl_plot);
    
    if nBad > 0
        fprintf('[plot_score_pressure] Removing %d / %d rows (%.2f%%) with Score outside [1,10] (or NaN/Inf).\n', ...
            nBad, nTot, 100*nBad/nTot);
    
        % Optional: show the unique bad values
        badVals = unique(tbl_plot.Score(isBad & ~isnan(tbl_plot.Score) & isfinite(tbl_plot.Score)));
        fprintf('Bad Score values found: %s\n', mat2str(badVals'));
    
        tbl_plot(isBad, :) = [];
    else
        fprintf('[plot_score_pressure] No out-of-range Score values found. Using all %d rows.\n', nTot);
    end
    
    
    
    
    
    % =========================
    % Tail-specific subject-wise z-score QC by pressure:
    %   P1: upper-tail only
    %   P3: two-tail
    %   P6: lower-tail only
    % =========================
    
    % ----- Parameters -----
    z_thr      = 3;   % z threshold (start 2.5–3.5)
    epsSD      = 1e-6;
    
    
    % Ensure categorical vars
    tbl_plot.Subject_cat  = categorical(tbl_plot.Subject_cat);
    tbl_plot.Pressure_cat = categorical(string(tbl_plot.Pressure_cat));
    tbl_plot.Pressure_cat = reordercats(tbl_plot.Pressure_cat, {'1','3','6'});
    
    % Keep only valid scores
    validScore = isfinite(tbl_plot.Score) & ~isnan(tbl_plot.Score) & (tbl_plot.Score >= 1) & (tbl_plot.Score <= 10);
    tbl_plot = tbl_plot(validScore, :);
    
    % Initialize QC fields
    tbl_plot.ignore_scoreQC = false(height(tbl_plot),1);
    tbl_plot.z_scoreQC      = nan(height(tbl_plot),1);
    
    % Group by subject × pressure
    gid = findgroups(tbl_plot.Subject_cat, tbl_plot.Pressure_cat);
    nGroups = max(gid);
    
    for g = 1:nGroups
        idx = (gid == g);
        y = tbl_plot.Score(idx);
    
        
        mu = mean(y);
        sd = std(y, 0);
    
        z = (y - mu) ./ (sd + epsSD);
        tbl_plot.z_scoreQC(idx) = z;
    
        % Determine tail rule based on this group's pressure
        % (All rows in idx share the same pressure level)
        pLevel = string(tbl_plot.Pressure_cat(find(idx,1,'first')));  % '1','3','6'
    
        switch pLevel
            case "1"  % P1: upper-tail only (implausibly high)
                flag = (z >  z_thr) & ((y - mu) >= 1);
    
            case "3"  % P3: two-tailed
                flag = (abs(z) > z_thr) & (abs(y - mu) >= 3);
    
            case "6"  % P6: lower-tail only (implausibly low)
                flag = (z < -z_thr) & ((mu - y) >= 2);
    
            otherwise
                flag = false(size(y)); % should not happen
        end
    
        tbl_plot.ignore_scoreQC(idx) = flag;
    end
    
    
    % ---- Summary ----
    nTot  = height(tbl_plot);
    nFlag = nnz(tbl_plot.ignore_scoreQC);
    
    fprintf('[ScoreQC tail-specific] Flagged %d / %d trials (%.2f%%). \n', ...
        nFlag, nTot, 100*nFlag/nTot);
    
    % Breakdown by pressure
    pressCats = categories(tbl_plot.Pressure_cat);
    for c = 1:numel(pressCats)
        idxP = (tbl_plot.Pressure_cat == pressCats{c});
        fprintf('  Pressure %s: flagged %d / %d (%.2f%%)\n', ...
            pressCats{c}, nnz(tbl_plot.ignore_scoreQC & idxP), nnz(idxP), ...
            100*nnz(tbl_plot.ignore_scoreQC & idxP)/max(nnz(idxP),1));
    end
    
    % % Optional: inspect a few flagged trials per pressure
    % if nFlag > 0
    %     disp('Example flagged trials (first 15):');
    %     outliers = tbl_plot(find(tbl_plot.ignore_scoreQC), {'Subject_cat','Pressure_cat','Score','z_scoreQC','ignore_scoreQC'});
    % end
    
    

    % ---- Cleaned table ----
    T_clean = tbl_plot(~tbl_plot.ignore_scoreQC, :);
    
    % ---- Trial count table: number of trials per (Pressure condition × Score) ----
    TT = T_clean;   % use your cleaned table; or tbl if you don't have tbl_plot
    
    % Long counts via findgroups/splitapply (very compatible)
    [gid, gPress, gScore] = findgroups(TT.Pressure_cat, TT.Score);
    N = splitapply(@numel, TT.Score, gid);
    
    % Convert pressure labels from '1','3','6' → 'P1','P3','P6'
    gPress = categorical("P" + string(gPress));
    
    countTblLong = table(gPress, gScore, N, ...
        'VariableNames', {'Pressure_cat','Score_int','Ntrials'});
    
    % Wide table
    countTblWide = unstack(countTblLong, 'Ntrials', 'Pressure_cat');
    
    % Ensure all score rows exist (1..10)
    allScores = table((1:10)', 'VariableNames', {'Score_int'});
    countTblWide = outerjoin(allScores, countTblWide, ...
        'Keys','Score_int', 'MergeKeys',true, 'Type','left');
    countTblWide = sortrows(countTblWide, 'Score_int');
    
    % Fill missing with zeros
    vn = countTblWide.Properties.VariableNames;
    for k = 1:numel(vn)
        if ~strcmp(vn{k}, 'Score_int')
            countTblWide.(vn{k})(isnan(countTblWide.(vn{k}))) = 0;
        end
    end
    
    % Add total per score row
    countTblWide.Total = zeros(size(countTblWide, 1), 1);
    for k = 1:numel(vn)
        if ~strcmp(vn{k}, 'Score_int')
            countTblWide.Total = countTblWide.Total + countTblWide.(vn{k});
        end
    end
    
    
    % ---- Add final row: totals per pressure (and grand total) ----
    totalRow = countTblWide(1,:);  % template row with same variables
    
    % Mark the score label for the total row
    % (If Score_int is numeric, we use NaN as placeholder)
    totalRow.Score_int = NaN;
    
    % For each pressure column, sum down the column
    vn = countTblWide.Properties.VariableNames;
    for k = 1:numel(vn)
        if ~strcmp(vn{k}, 'Score_int')
            totalRow.(vn{k}) = sum(countTblWide.(vn{k}));
        end
    end
    
    % Append
    countTblWide = [countTblWide; totalRow];
    
    
    
    
    % For each (Score, Pressure), count unique subjects
    [gidSP, gScore, gP] = findgroups(TT.Score, TT.Pressure_cat);
    
    % splitapply with an anonymous function that counts unique subject IDs in each group
    nSubj = splitapply(@(s) numel(unique(s)), TT.Subject_cat, gidSP);
    
    % Convert pressure labels from '1','3','6' → 'P1','P3','P6'
    gP = categorical("P" + string(gP));
    
    subjTblLong = table(gScore, gP, nSubj, ...
        'VariableNames', {'Score_int','Pressure','N_Subject'});
    
    % Pivot to wide: columns will be P1/P3/P6
    subjTblWide = unstack(subjTblLong, 'N_Subject', 'Pressure');
    
    % Fill missing subject counts with 0
    vn = subjTblWide.Properties.VariableNames;
    for k = 1:numel(vn)
        if ~strcmp(vn{k}, 'Score_int')
            subjTblWide.(vn{k})(isnan(subjTblWide.(vn{k}))) = 0;
        end
    end
    
    % Rename columns to requested names
    % (after Total column)
    subjTblWide.Properties.VariableNames = ...
        {'Score_int','N_Subject_P1','N_Subject_P3','N_Subject_P6'};
    
    % Merge into countTblWide (match on Score_int)
    countTblWide = outerjoin(countTblWide, subjTblWide, ...
        'Keys','Score_int', 'MergeKeys', true, 'Type','left');
    
    % Here we set totals row subject counts to number of unique subjects per pressure overall.
    isTotalRow = isnan(countTblWide.Score_int);
    if any(isTotalRow)
        nSubP1 = numel(unique(T_clean.Subject_cat(TT.Pressure_cat == '1')));
        nSubP3 = numel(unique(T_clean.Subject_cat(TT.Pressure_cat == '3')));
        nSubP6 = numel(unique(T_clean.Subject_cat(TT.Pressure_cat == '6')));
    
        countTblWide.N_Subject_P1(isTotalRow) = nSubP1;
        countTblWide.N_Subject_P3(isTotalRow) = nSubP3;
        countTblWide.N_Subject_P6(isTotalRow) = nSubP6;
    end
    
    
    
    disp('Trial counts per Score × Pressure condition:');
    disp(countTblWide);
    
    


    
    %% Create figure
    figure('Color','w','Position',[120 120 720 520]);
    ax = axes; hold(ax,'on');

    P1_color = [1, 115, 178]/255;
    P3_color = [222, 143, 5]/255;
    P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
    cols = [P1_color; P3_color; P6_color];
    
    % ---- Layout offsets (tune these) ----
    dxBox = -0.10;   % boxcharts shifted left
    dxSub = +0.10;   % subject mean points shifted right
    x = [1, 2, 3];
    jitterSub = 0.06;  % jitter around the subject-mean x position
    rng(9);
    
    % % -------- Layer 1: Box charts (shifted LEFT) --------
    % for c = 1:nCond
    %     y = T_clean.Score(T_clean.Pressure_cat == pressCats{c});
    %     y = y(~isnan(y));
    % 
    %     % x locations for this condition (shifted left)
    %     xBox = repmat(x(c) + dxBox, size(y));
    % 
    %     bc = boxchart(xBox, y);
    %     bc.BoxFaceColor = cols(c,:);
    %     bc.BoxFaceAlpha = 0.5;
    %     bc.MarkerStyle  = 'none';   % hide boxchart outlier markers
    %     bc.LineWidth    = 1.4;
    % 
    %     % Optional: make whiskers/median more visible
    %     % bc.WhiskerLineColor = [0 0 0];
    %     % bc.MedianLineColor  = [0 0 0];
    % end
    
    % -------- Layer 1: Boxplots with controlled whiskers --------
    nCond = numel(pressCats);
    for c = 1:nCond
        y = T_clean.Score(T_clean.Pressure_cat == pressCats{c});
        y = y(~isnan(y));
    
        % x position shifted left
        xPos = x(c) + dxBox;
    
        % Capture existing objects before boxplot
        ax = gca;
        
        oldBox   = findobj(ax,'Tag','Box');
        oldMed   = findobj(ax,'Tag','Median');
        oldOut   = findobj(ax,'Tag','Outliers');
        oldLW    = findobj(ax,'Tag','Lower Whisker');
        oldUW    = findobj(ax,'Tag','Upper Whisker');
        oldLAdj  = findobj(ax,'Tag','Lower Adjacent Value');
        oldUAdj  = findobj(ax,'Tag','Upper Adjacent Value');
        
        % ---- draw ----
        boxplot(y, 'Positions', xPos, ...
            'Widths', 0.2, ...
            'Whisker', 1.0, ...
            'Colors', cols(c,:), ...
            'Symbol', '');  % hide outlier markers (still created but empty)
        
        % ---- get newly created handles ----
        newBox  = setdiff(findobj(ax,'Tag','Box'), oldBox);
        newMed  = setdiff(findobj(ax,'Tag','Median'), oldMed);
        newOut  = setdiff(findobj(ax,'Tag','Outliers'), oldOut);
        newLW   = setdiff(findobj(ax,'Tag','Lower Whisker'), oldLW);
        newUW   = setdiff(findobj(ax,'Tag','Upper Whisker'), oldUW);
        newLAdj = setdiff(findobj(ax,'Tag','Lower Adjacent Value'), oldLAdj);
        newUAdj = setdiff(findobj(ax,'Tag','Upper Adjacent Value'), oldUAdj);
        
        % ---- style parameters ----
        whiskCol = 0.9*cols(c,:);  % or use a darker version of cols(c,:)
        lwWhisk  = 2;
        lwBox    = 2;
        lwMed    = 2;
        
        % ---- apply styles ----
        set(newLW,   'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
        set(newUW,   'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
        
        % These are the horizontal caps in your version:
        set(newLAdj, 'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
        set(newUAdj, 'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
        
        set(newMed,  'LineWidth', lwMed, 'Color', whiskCol);
        set(newBox,  'LineWidth', lwBox);  % edge thickness (color is handled by your fill/edge)
        
        % Optional: if any outlier marker still appears, force-hide it:
        set(newOut, 'Marker', 'none');
    
    
        % % Fill the box manually (boxplot does not support FaceAlpha)
        % After boxplot, fill the box area with a patch (alpha)
        for k = 1:numel(newBox)
            X = get(newBox(k),'XData');
            Y = get(newBox(k),'YData');
            patch(X, Y, cols(c,:), ...
                'FaceAlpha', 0.4, ...
                'EdgeColor', whiskCol, ...
                'LineWidth', lwBox);
        end
    end
    
    

    % Compute subject means per condition
    subCats = categories(T_clean.Subject_cat);
    nSub  = numel(subCats);
    subjMean = nan(nSub, nCond);
    
    for s = 1:nSub
        for c = 1:nCond
            idx = T_clean.Subject_cat == subCats{s} & ...
                  T_clean.Pressure_cat == pressCats{c};
            subjMean(s,c) = mean(T_clean.Score(idx), 'omitnan');
        end
    end

    % -------- Anchored jitter for subject means (shifted RIGHT) --------
    xJit = (rand(nSub,nCond) - 0.5) * 2 * jitterSub;  % per-subject per-condition
    

    % -------- Layer 2: Subject trajectories (thin grey, connect jittered points) --------
    for s = 1:nSub
        ys = subjMean(s,:);
        valid = ~isnan(ys);
    
        if nnz(valid) >= 2
            xLine = (x(valid) + dxSub) + xJit(s,valid);
            plot(xLine, ys(valid), '-', ...
                'Color', 0.6*[1 1 1 0.7], 'LineWidth', 0.5);
        end
    end
    
    % -------- Layer 3: Subject mean circles (shifted RIGHT) --------
    for c = 1:nCond
        ys = subjMean(:,c);
        valid = ~isnan(ys);
    
        xPts = (x(c) + dxSub) + xJit(valid,c);
    
        edgeCol = 0.9*cols(c,:);
    
        scatter(xPts, ys(valid), 46, 'o', ...
            'MarkerFaceColor', cols(c,:), ...
            'MarkerEdgeColor', edgeCol, ...
            'MarkerFaceAlpha', 0.4, ...
            'LineWidth', 1);
    end





    % ===== LMM layer: estimated marginal means (fixed effects) ± 95% CI =====
    % Assumes:
    %   - lme_cat exists (fitlme output)
    %   - Pressure_cat levels are {'1','3','6'}
    %   - Current axes is the plot you want to add to

    lme_cat = fitlme(T_clean, ...
        'Score ~ 1 + Pressure_cat + (1 + Pressure_cat | Subject_cat)', ...
        'FitMethod','ML');
    % disp(lme_cat)
    
    ax = gca; hold(ax,'on');
    
    % X positions for the three conditions (centered on tick marks)
    xEMM = x + dxBox;
    pressLevels = {'1','3','6'};
    
    % Build a "new data" table for prediction.
    % For marginal means, Subject_cat can be any valid level because we set Conditional=false.
    % subRef = lme_cat.Variables.Subject_cat(1);  % pick a valid subject level from model data
    % 
    % newTbl = table( ...
    %     categorical(pressLevels(:), pressLevels), ...              % Pressure_cat
    %     repmat(subRef, numel(pressLevels), 1), ...                % Subject_cat
    %     'VariableNames', {'Pressure_cat','Subject_cat'} );


    subRef = categorical({'7'}, categories(lme_cat.Variables.Subject_cat));
    % (Optional) safety check
    if ~ismember(subRef, lme_cat.Variables.Subject_cat)
        error('Subject %s is not a valid level in the fitted model.', wantedID);
    end

    newTbl = table( ...
        categorical(pressLevels(:), pressLevels), ...
        repmat(subRef, numel(pressLevels), 1), ...
        'VariableNames', {'Pressure_cat','Subject_cat'} );



    
    % Predict marginal (fixed-effects only) means and 95% CI
    [emm, emmCI] = predict(lme_cat, newTbl, ...
        'Conditional', false, 'Alpha', 0.05);
    
    
    % Convert CI to symmetric error bars
    errLow  = emm - emmCI(:,1);
    errHigh = emmCI(:,2) - emm;
    
    % Plot: thick black line + filled black markers + error bars
    h = errorbar(ax, xEMM, emm, errLow, errHigh, 'o-', ...
        'Color', 'k', ...
        'MarkerFaceColor', 'k', ...
        'MarkerEdgeColor', 'k', ...
        'MarkerSize', 7, ...
        'LineWidth', 2.4, ...
        'CapSize', 10);
    
    % Optional: place this layer on top
    uistack(h, 'top');



    
    % Axis formatting
    xlim([0.5 nCond+0.5]);
    ylim([0.5 10.5]);

    ylh = ylabel('Subjective Rating');
    ylh.FontWeight = "bold";
    ylh.Position(1) = ylh.Position(1) - 0.2;
    xlh = xlabel('Pressure Condition');
    xlh.FontWeight = "bold";
    xlh.Position(2) = xlh.Position(2) - 1;

    set(gca, 'XTick', x, 'XTickLabel', {'Low', 'Medium', 'High'})
    set(gca, 'FontSize', 16, 'Box', 'off')

    pos = get(gca, 'Position');
    set(gca, 'Position', [pos(1)*1.4, pos(2)*1.6, pos(3)*0.9, pos(4)*0.9])



end