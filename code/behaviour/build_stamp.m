function stamp = build_stamp(cfg, extra)
% BUILD_STAMP  Record what produced a master table, so a stale copy is visible.
%
%   stamp = build_stamp(cfg)
%   stamp = build_stamp(cfg, extra)
%
% Returns a struct saved alongside every master table. extra is an optional
% struct whose fields are merged in, for anything builder-specific such as the
% screening policy.
%
% WHY. The three small tables are committed to the repository, because a
% reproducer needs them and cannot rebuild them without the stage 2 per-trial
% data. A committed output is a hazard: change a flag in a builder and the
% committed table still loads, still has the right columns, and is quietly
% out of date. Nothing about it looks wrong.
%
% This does not prevent that. It makes it detectable: the stamp records when
% the table was built, from which builder, with which builder file date, and
% at which commit. Print it before trusting a table you did not build
% yourself, and compare builderModified against the file on disk.
%
% Fields
%   written          when this table was built
%   builder          the function that built it
%   builderModified  last-modified date of that function's source file
%   subjects         the participant list it covers
%   matlab           MATLAB version
%   gitCommit        repository commit, or '(not a git checkout)'
%
% See also BUILD_EMG_MASTER, BUILD_TRACKING_MASTER, BUILD_BEHAVIOUR_TABLE.

    if nargin < 1 || isempty(cfg)
        cfg = kneeexo_config();
    end

    % The caller, which is the builder. dbstack(1) is one frame up.
    st = dbstack(1, '-completenames');
    if isempty(st)
        builder = '(called from the command line)';
        builderFile = '';
    else
        builder = st(1).name;
        builderFile = st(1).file;
    end

    stamp = struct();
    stamp.written = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
    stamp.builder = builder;

    stamp.builderModified = '(unknown)';
    if ~isempty(builderFile) && exist(builderFile, 'file')
        d = dir(builderFile);
        stamp.builderModified = datestr(d.datenum, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST>
    end

    stamp.subjects = cfg.subjects;
    stamp.matlab   = version;
    stamp.gitCommit = git_commit(cfg.root);

    if nargin >= 2 && ~isempty(extra) && isstruct(extra)
        f = fieldnames(extra);
        for k = 1:numel(f)
            stamp.(f{k}) = extra.(f{k});
        end
    end

end


% ------------------------------------------------------------------------
function c = git_commit(repoRoot)
% The short commit of the repository, when git is available and this is a
% checkout. Wrapped because neither is guaranteed: a reproducer may have
% unpacked a zip, and MATLAB may be running where git is not on the path.

    c = '(not a git checkout)';

    if isempty(repoRoot) || ~isfolder(fullfile(repoRoot, '.git'))
        return
    end

    try
        [status, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', repoRoot));
        if status == 0
            c = strtrim(out);

            % A dirty tree means the commit does not describe the code that
            % ran, which is worth saying rather than implying precision.
            [s2, o2] = system(sprintf('git -C "%s" status --porcelain', repoRoot));
            if s2 == 0 && ~isempty(strtrim(o2))
                c = [c, ' (working tree modified)'];
            end
        end
    catch
        % Leave the default. A missing stamp field is a nuisance; an error
        % here would abandon a build that has already done the real work.
    end

end