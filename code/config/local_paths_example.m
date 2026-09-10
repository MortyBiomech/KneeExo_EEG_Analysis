function local = local_paths_example()
% LOCAL_PATHS  Paths that are specific to this machine.
%
% Copy this file to local_paths.m in the same folder and edit it. That copy is
% gitignored, so your paths never enter the repository and never conflict with
% anyone else's.
%
% Every field is optional. A field you leave out, or leave empty, falls back to
% the default in kneeexo_config.m. Delete the lines you do not need.
%
% You only need this file to re-run the pipeline from the recordings. To
% reproduce the figures from the shipped derived data, you need nothing here.

    % Where you downloaded the dataset. This is the folder that contains
    % 0_source_data, 1_BIDS_data, 2_raw-EEGLAB and so on.
    local.raw = 'D:\Morteza\MyProjects\ANSYMB2024\data';

    % Toolboxes. Leave these out unless auto-detection fails, which it only
    % does when the toolbox is not on the MATLAB path at all.
    % local.eeglab    = 'D:\Morteza\Toolboxes\EEGLAB\eeglab2026.0.0';
    % local.fieldtrip = 'D:\Morteza\Toolboxes\fieldtrip';
    % local.xdf       = 'D:\Morteza\Toolboxes\xdf-Matlab';
    % local.bemobil   = 'D:\Morteza\Toolboxes\bemobil-pipeline';

end