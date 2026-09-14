function f = resolve_derived_file(subject_id, name, working_folder)
% RESOLVE_DERIVED_FILE  Locate a published per-participant event file.
%
%   f = resolve_derived_file(subject_id, name)
%   f = resolve_derived_file(subject_id, name, working_folder)
%
% Returns the full path, or an empty string when the file is nowhere to be
% found. Two locations are checked, in this order:
%
%   1. <cfg.derived>/Events/sub-<N>/<name>
%      the shipped copy, which is what a reproducer has
%   2. <working_folder>/sub-<N>/<name>
%      an optional working location, for a file that has just been produced
%      locally and not yet copied into the repository
%
% Examples
%   resolve_derived_file(7, 'events_with_FlxExt.txt')
%   resolve_derived_file(7, 'sub-7_Trials_encoder_events.mat', cfg.trialsEvents)
%
% ONE SHIPPED FOLDER, DELIBERATELY. Both event files sit side by side in
% <cfg.derived>/Events/sub-<N>/: the text table that add_events imports, and
% the encoder events that run_multimodal_trials reads. They describe the same
% flexion and extension events and come from the same manual step, so
% splitting them across two folders named after pipeline stages only made a
% reader hunt for the second one. The working tree keeps its numbered stage
% folders, because those mirror the order things are computed in; the
% published copy is arranged for somebody who has never seen the pipeline.
%
% cfg.derived comes from kneeexo_config, so this works from a fresh clone with
% no configuration at all.

    f = '';
    sub = ['sub-', num2str(subject_id)];

    cfg = kneeexo_config();

    candidate = fullfile(cfg.derived, 'Events', sub, name);
    if exist(candidate, 'file')
        f = candidate;
        return
    end

    if nargin >= 3 && ~isempty(working_folder)
        candidate = fullfile(working_folder, sub, name);
        if exist(candidate, 'file')
            f = candidate;
        end
    end

end