function add_code_paths(cfg, varargin)
% ADD_CODE_PATHS  Put the analysis code on the MATLAB path, and nothing else.
%
%   add_code_paths()
%   add_code_paths(cfg)
%   add_code_paths(cfg, 'bemobil')
%
% Replaces the earlier bootstrap line addpath(genpath(cfg.code)), which put
% code/archive on the path along with everything else. Nothing in archive is
% meant to run: it holds the superseded versions of functions that are still
% live under another name, including two with known bugs. Having them findable
% by which() is how somebody ends up calling one by accident.
%
% Pass 'bemobil' in the stages that need the BeMoBIL pipeline, that is,
% data_processing/run_preprocessing.m and study/run_group_clustering.m. It is
% not added by default because BeMoBIL brings a large tree of its own, and a
% toolbox that is on the path in every stage is a toolbox that can shadow a
% function in a stage that never asked for it.
%
% Adding the path is all this does. BeMoBIL builds on EEGLAB, so EEGLAB still
% has to be started before any bemobil_ function is CALLED, which both stages
% do a few lines further down.
%
% See also KNEEEXO_CONFIG.

    if nargin < 1 || isempty(cfg)
        cfg = kneeexo_config();
    end

    wantBemobil = any(strcmpi(varargin, 'bemobil'));


    %% The analysis code, minus archive
    % genpath already skips .git, private and class or package folders, so
    % archive is the only name that has to be filtered here.
    folders = strsplit(genpath(cfg.code), pathsep);
    folders = folders(~cellfun(@isempty, folders));

    isArchive = contains(folders, [filesep 'archive']);
    addpath(strjoin(folders(~isArchive), pathsep));


    %% BeMoBIL, only when a stage asks for it
    if ~wantBemobil
        return
    end

    if isempty(cfg.bemobil)
        error('add_code_paths:NoBemobil', ...
            ['This stage needs the BeMoBIL pipeline and cfg.bemobil is ' ...
             'empty.\n\nIt ships as a git submodule. In the repository ' ...
             'root run\n\n    git submodule update --init\n\nor set ' ...
             'local.bemobil in config/local_paths.m to point at your own ' ...
             'clone.']);
    end

    listing = dir(cfg.bemobil);
    listing = listing(~ismember({listing.name}, {'.', '..'}));

    if ~isfolder(cfg.bemobil) || isempty(listing)
        error('add_code_paths:EmptyBemobil', ...
            ['The BeMoBIL folder\n  %s\ndoes not exist or is empty. An ' ...
             'empty submodule folder means the submodule was never checked ' ...
             'out. In the repository root run\n\n    git submodule update ' ...
             '--init\n'], cfg.bemobil);
    end

    addpath(genpath(cfg.bemobil));

    % A folder with the right name is not proof of the right contents.
    if isempty(which('bemobil_process_all_EEG_preprocessing'))
        error('add_code_paths:BemobilIncomplete', ...
            ['%s is on the path but bemobil_process_all_EEG_preprocessing ' ...
             'was not found in it. Check that this is the BeMoBIL pipeline ' ...
             'repository and not something else.'], cfg.bemobil);
    end

end