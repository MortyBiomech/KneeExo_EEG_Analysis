% remove duplicates in the list of parameters
% -------------------------------------------
function cella = removedup(cella)
[tmp, indices] = unique_bc(cella(1:2:end));
if length(tmp) ~= length(cella)/2
    %fprintf('Warning: duplicate ''key'', ''val'' parameter(s), keeping the last one(s)\n');
end
cella = cella(sort(union(indices*2-1, indices*2)));
end