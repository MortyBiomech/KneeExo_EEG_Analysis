function f = resolve_derived_file(subfolder, subject_id, name, extra_root)
% RESOLVE_DERIVED_FILE  Locate a per-participant derived file.
%
%   f = resolve_derived_file(subfolder, subject_id, name)
%   f = resolve_derived_file(subfolder, subject_id, name, extra_root)
%
% Returns the full path, or an empty string when the file is nowhere to be
% found. Two locations are checked, in this order:
%
%   1. <cfg.derived>/<subfolder>/sub-<N>/<name>
%      the shipped copy, which is what a reproducer has
%   2. <extra_root>/<subfolder>/sub-<N>/<name>
%      an optional working location, for a file that has just been produced
%      locally and not yet copied into the repository
%
% Examples
%   resolve_derived_file('Events', 7, 'events_with_FlxExt.txt')
%   resolve_derived_file('6_0_Trials_Info_and_Events', 7, ...
%       'sub-7_Trials_encoder_events.mat', cfg.raw)
%
% cfg.derived comes from kneeexo_config, so this works from a fresh clone with
% no configuration at all.

    f = '';
    sub = ['sub-', num2str(subject_id)];

    cfg = kneeexo_config();

    candidate = fullfile(cfg.derived, subfolder, sub, name);
    if exist(candidate, 'file')
        f = candidate;
        return
    end

    if nargin >= 4 && ~isempty(extra_root)
        candidate = fullfile(extra_root, subfolder, sub, name);
        if exist(candidate, 'file')
            f = candidate;
        end
    end

end