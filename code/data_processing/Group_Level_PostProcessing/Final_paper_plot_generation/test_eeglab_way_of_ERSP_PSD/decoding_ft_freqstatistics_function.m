
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% is called on the line 246 at decoding_statcondfieldtrip_function.m

% function [stat] = ft_freqstatistics(cfg, varargin8)

% stat            = ft_freqstatistics(cfg, newdata{:});
cfg8 = cfg;
varargin8 = {newdata{:}};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



% FT_FREQSTATISTICS computes significance probabilities and/or critical
% values of a parametric statistical test or a non-parametric permutation
% test.
%
% Use as
%   [stat] = ft_freqstatistics(cfg, freq1, freq2, ...)
% where the input data is the result from FT_FREQANALYSIS, FT_FREQDESCRIPTIVES
% or from FT_FREQGRANDAVERAGE.
%
% The configuration can contain the following options for data selection
%   cfg.channel     = Nx1 cell-array with selection of channels (default = 'all'),
%                     see FT_CHANNELSELECTION for details
%   cfg.latency     = [begin end] in seconds or 'all' (default = 'all')
%   cfg.frequency   = [begin end], can be 'all'       (default = 'all')
%   cfg.avgoverchan = 'yes' or 'no'                   (default = 'no')
%   cfg.avgovertime = 'yes' or 'no'                   (default = 'no')
%   cfg.avgoverfreq = 'yes' or 'no'                   (default = 'no')
%   cfg.parameter   = string                          (default = 'powspctrm')
%
% If you specify cfg.correctm='cluster', then the following is required
%   cfg.neighbours  = neighbourhood structure, see FT_PREPARE_NEIGHBOURS
%
% Furthermore, the configuration should contain
%   cfg.method       = different methods for calculating the significance probability and/or critical value
%                    'montecarlo'    get Monte-Carlo estimates of the significance probabilities and/or critical values from the permutation distribution,
%                    'analytic'      get significance probabilities and/or critical values from the analytic reference distribution (typically, the sampling distribution under the null hypothesis),
%                    'stats'         use a parametric test from the MATLAB statistics toolbox,
%                    'crossvalidate' use crossvalidation to compute predictive performance
%
%   cfg.design       = Nxnumobservations: design matrix (for examples/advice, please see the Fieldtrip wiki,
%                      especially cluster-permutation tutorial and the 'walkthrough' design-matrix section)
%
% The other cfg options depend on the method that you select. You
% should read the help of the respective subfunction FT_STATISTICS_XXX
% for the corresponding configuration options and for a detailed
% explanation of each method.
%
% To facilitate data-handling and distributed computing you can use
%   cfg.inputfile   =  ...
%   cfg.outputfile  =  ...
% If you specify one of these (or both) the input data will be read from a *.mat
% file on disk and/or the output data will be written to a *.mat file. These mat
% files should contain only a single variable, corresponding with the
% input/output structure.
%
% See also FT_FREQANALYSIS, FT_FREQDESCRIPTIVES, FT_FREQGRANDAVERAGE

% Copyright (C) 2005-2014, Robert Oostenveld & Jan-Mathijs Schoffelen
%
% This file is part of FieldTrip, see http://www.fieldtriptoolbox.org
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id$

% these are used by the ft_preamble/ft_postamble function and scripts
ft_revision = '$Id$';
ft_nargin   = 2;
ft_nargout  = 1;

% do the general setup of the function
ft_defaults
ft_preamble init
ft_preamble debug
ft_preamble loadvar varargin8
ft_preamble provenance varargin8

ft_preamble randomseed

% the ft_abort variable is set to true or false in ft_preamble_init
if ft_abort
  return
end

% check if the input data is valid for this function
for i=1:length(varargin8)
  varargin8{i} = ft_checkdata(varargin8{i}, 'datatype', 'freq', 'feedback', 'no');
end

% check if the input cfg is valid for this function
cfg8 = ft_checkconfig(cfg8, 'forbidden',  {'channels'}); % prevent accidental typos, see issue 1729
cfg8 = ft_checkconfig(cfg8, 'required',   {'method', 'design'});
cfg8 = ft_checkconfig(cfg8, 'renamed',    {'approach',   'method'});
cfg8 = ft_checkconfig(cfg8, 'forbidden',  {'transform'});
cfg8 = ft_checkconfig(cfg8, 'forbidden',  {'trials'}); % this used to be present until 24 Dec 2014, but was deemed too confusing by Robert

% set the defaults
cfg8.parameter   = ft_getopt(cfg8, 'parameter'); % default is set below
cfg8.correctm    = ft_getopt(cfg8, 'correctm');
cfg8.channel     = ft_getopt(cfg8, 'channel',     'all');
cfg8.latency     = ft_getopt(cfg8, 'latency',     'all');
cfg8.frequency   = ft_getopt(cfg8, 'frequency',   'all');
cfg8.avgoverchan = ft_getopt(cfg8, 'avgoverchan', 'no');
cfg8.avgovertime = ft_getopt(cfg8, 'avgovertime', 'no');
cfg8.avgoverfreq = ft_getopt(cfg8, 'avgoverfreq', 'no');

if isempty(cfg8.parameter)
  if isfield(varargin8{1}, 'powspctrm')
    cfg8.parameter = 'powspctrm';
  end
end

% ensure that the data in all inputs has the same channels, time-axis, etc.
tmpcfg = keepfields(cfg8, {'frequency', 'avgoverfreq', 'latency', 'avgovertime', 'channel', 'avgoverchan', 'parameter', 'select', 'nanmean', 'showcallinfo', 'trackcallinfo', 'trackusage', 'trackdatainfo', 'trackmeminfo', 'tracktimeinfo', 'checksize'});
[varargin8{:}] = ft_selectdata(tmpcfg, varargin8{:});
% restore the provenance information
[cfg8, varargin8{:}] = rollback_provenance(cfg8, varargin8{:});

% neighbours are required for clustering with multiple channels
if strcmp(cfg8.correctm, 'cluster') && length(varargin8{1}.label)>1
  % this is limited to reading neighbours from disk and/or selecting channels
  % the user should call FT_PREPARE_NEIGHBOURS directly for the actual construction
  tmpcfg = keepfields(cfg8, {'neighbours', 'channel', 'showcallinfo', 'trackcallinfo', 'trackusage', 'trackdatainfo', 'trackmeminfo', 'tracktimeinfo', 'checksize'});
  cfg8.neighbours = ft_prepare_neighbours(tmpcfg);
end

dimord = getdimord(varargin8{1}, cfg8.parameter);
dimtok = tokenize(dimord, '_');
dimsiz = getdimsiz(varargin8{1}, cfg8.parameter, numel(dimtok));
rptdim = find( strcmp(dimtok, 'subj') |  strcmp(dimtok, 'rpt') |  strcmp(dimtok, 'rpttap'));
datdim = find(~strcmp(dimtok, 'subj') & ~strcmp(dimtok, 'rpt') & ~strcmp(dimtok, 'rpttap'));
datsiz = dimsiz(datdim);

% pass these fields to the low-level functions, they should be removed further down
cfg8.dimord = sprintf('%s_', dimtok{datdim});
cfg8.dimord = cfg8.dimord(1:end-1); % remove trailing _
cfg8.dim    = dimsiz(datdim);

if isempty(rptdim)
  % repetitions are across multiple inputs
  dat = nan(prod(dimsiz), length(varargin8));
  for i=1:length(varargin8)
    tmp = varargin8{i}.(cfg8.parameter);
    dat(:,i) = tmp(:);
  end
else
  % repetitions are within inputs
  dat = cell(size(varargin8));
  for i=1:length(varargin8)
    tmp = varargin8{i}.(cfg8.parameter);
    if rptdim~=1
      % move the repetitions to the first dimension
      tmp = permute(tmp, [rptdim datdim]);
    end
    dat{i} = reshape(tmp, size(tmp,1), []);
  end
  dat = cat(1, dat{:});   % repetitions along 1st dimension
  dat = dat';             % repetitions along 2nd dimension
end

if size(cfg8.design,2)~=size(dat,2)
  cfg8.design = transpose(cfg8.design);
end

design = cfg8.design;

% fetch function handle to the intermediate-level statistics function
statmethod = ft_getuserfun(cfg8.method, 'statistics');
if isempty(statmethod)
  ft_error('could not find the corresponding function for cfg.method="%s"\n', cfg8.method);
else
  ft_info('using "%s" for the statistical testing\n', func2str(statmethod));
end

% check that the design completely describes the data
if size(dat,2) ~= size(cfg8.design,2)
  ft_error('the length of the design matrix (%d) does not match the number of observations in the data (%d)', size(cfg8.design,2), size(dat,2));
end

% determine the number of output arguments
try
  % the nargout function in MATLAB 6.5 and older does not work on function handles
  num = nargout(statmethod);
catch
  num = 1;
end

% perform the statistical test
if num>1
  [stat, cfg8] = statmethod(cfg8, dat, design);
  cfg8         = rollback_provenance(cfg8); % ensure that changes to the cfg are passed back to the right level
else
  [stat] = statmethod(cfg8, dat, design); % ft_statfun_depsamplesFunivariate
end

if ~isstruct(stat)
  % only the probability was returned as a single matrix, reformat into a structure
  stat = struct('prob', stat);
end

% the statistical output contains multiple elements, e.g. F-value, beta-weights and probability
fn = fieldnames(stat);

for i=1:length(fn)
  if numel(stat.(fn{i}))==prod(datsiz)
    % reformat into the same dimensions as the input data
    stat.(fn{i}) = reshape(stat.(fn{i}), [datsiz 1]);
  end
end

% describe the dimensions of the output data
stat.dimord = cfg8.dimord;

% copy the descripive fields into the output
stat = copyfields(varargin8{1}, stat, {'freq', 'time', 'label', 'elec', 'grad', 'opto'});

% these were only present to inform the low-level functions
cfg8 = removefields(cfg8, {'dim', 'dimord'});

% do the general cleanup and bookkeeping at the end of the function
ft_postamble debug
ft_postamble randomseed
ft_postamble previous   varargin8
ft_postamble provenance stat
ft_postamble history    stat
ft_postamble savevar    stat
