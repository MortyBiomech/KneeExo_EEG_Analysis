function map = emg_sensor_replacement(subject_id, session_index)
% EMG_SENSOR_REPLACEMENT  Sensor substitutions that happened during a
% recording, as a lookup instead of a dialog.
%
%   map = emg_sensor_replacement(subject_id, session_index)
%
% Returns an n x 2 matrix, [new_sensor old_sensor; ...], listing the rows of
% the EMG stream that have to be moved back onto the rows of the sensors
% they replaced. Returns [] when nothing was replaced for that participant
% and session.
%
% Background: the batteries of some Delsys sensors ran out during one
% recording and the sensors were swapped for spares. From that session on
% the EMG stream carries the new sensor ids as extra rows, while the rows of
% the dead sensors are still present and empty. concatenate_runs moves the
% new rows onto the old positions and deletes the leftovers, so that all
% sessions can be concatenated.
%
% This used to be typed into an inputdlg on every run. It is a property of
% the recording, not a choice, so it belongs in a table that ships with the
% code.

    map = [];

    switch subject_id

        case 8
            % The original sensors 2 to 5 lost battery during the session
            % and were replaced by sensors 12 to 15. Applies to every
            % session after the first.
            if session_index >= 2
                map = [12 2; 13 3; 14 4; 15 5];
            end

        otherwise
            % Nothing was replaced.

    end

end