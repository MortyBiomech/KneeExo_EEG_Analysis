% remove fields and ignore fields who are absent
% ----------------------------------------------
function s = myrmfield(s, f);

for index = 1:length(f)
    if isfield(s, f{index})
        s = rmfield(s, f{index});
    end
end
end