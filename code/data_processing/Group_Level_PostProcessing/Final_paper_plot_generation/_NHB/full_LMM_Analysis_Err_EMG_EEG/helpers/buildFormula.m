function formula = buildFormula(yVar, fixedVars, subjectVar, varargin)
% buildFormula  Construct an LMM formula string for fitlme.
%
% Usage:
%   f = buildFormula('Score', {'Pressure'}, 'Subject_cat');
%   f = buildFormula('Score', {'Pressure','ErrorRMS','EffortIndex'}, 'Subject_cat', ...
%                    'RandomSlopes', {'Pressure'}, 'IncludeIntercept', true);
%
% Inputs:
%   yVar       : char/string, response variable name (e.g., 'Score')
%   fixedVars  : cellstr or string array of fixed effect terms, e.g. {'Pressure','ErrorRMS'}
%                Terms can be variable names or composite terms like 'Pressure:ErrorRMS'
%   subjectVar : char/string, grouping variable for random effects (e.g., 'Subject_cat')
%
% Name-Value options:
%   'IncludeIntercept' : logical (default true) -> include "1" or "0"
%   'RandomIntercept'  : logical (default true) -> include intercept in random term
%   'RandomSlopes'     : cellstr/string array of predictor names for random slopes (default {})
%   'RandomTerm'       : char/string to override random effects completely (default "")
%                        e.g. '(1 + Pressure | Subject_cat)'
%
% Output:
%   formula : char formula string usable in fitlme()

% ---- Parse inputs ----
p = inputParser;
p.addRequired('yVar',        @(x) ischar(x) || isstring(x));
p.addRequired('fixedVars',   @(x) iscellstr(x) || isstring(x) || isempty(x));
p.addRequired('subjectVar',  @(x) ischar(x) || isstring(x));

p.addParameter('IncludeIntercept', true,  @(x) islogical(x) && isscalar(x));
p.addParameter('RandomIntercept',  true,  @(x) islogical(x) && isscalar(x));
p.addParameter('RandomSlopes',     {},    @(x) iscellstr(x) || isstring(x) || isempty(x));
p.addParameter('RandomTerm',       "",    @(x) ischar(x) || isstring(x));

p.parse(yVar, fixedVars, subjectVar, varargin{:});

yVar      = string(p.Results.yVar);
subjectVar= string(p.Results.subjectVar);

fixedVars = p.Results.fixedVars;
if isempty(fixedVars)
    fixedVars = string.empty(1,0);
else
    fixedVars = string(fixedVars);
end

includeIntercept = p.Results.IncludeIntercept;
randIntercept    = p.Results.RandomIntercept;
randSlopes       = p.Results.RandomSlopes;
randTermOverride = string(p.Results.RandomTerm);

if isempty(randSlopes)
    randSlopes = string.empty(1,0);
else
    randSlopes = string(randSlopes);
end

% ---- Build fixed part ----
if includeIntercept
    fixedParts = ["1", fixedVars];
else
    fixedParts = ["0", fixedVars];
end

% Remove empties (in case fixedVars was empty)
fixedParts = fixedParts(strlength(fixedParts) > 0);

fixedStr = strjoin(fixedParts, " + ");

% ---- Build random part ----
if strlength(randTermOverride) > 0
    randStr = randTermOverride;  % user-specified complete random term
else
    reParts = string.empty(1,0);
    if randIntercept
        reParts(end+1) = "1";
    end
    if ~isempty(randSlopes)
        reParts = [reParts, randSlopes];
    end

    if isempty(reParts)
        randStr = "";  % no random effects
    else
        randStr = "(" + strjoin(reParts, " + ") + " | " + subjectVar + ")";
    end
end

% ---- Combine ----
if strlength(randStr) > 0
    formula = yVar + " ~ " + fixedStr + " + " + randStr;
else
    formula = yVar + " ~ " + fixedStr;
end

formula = char(formula);
end
