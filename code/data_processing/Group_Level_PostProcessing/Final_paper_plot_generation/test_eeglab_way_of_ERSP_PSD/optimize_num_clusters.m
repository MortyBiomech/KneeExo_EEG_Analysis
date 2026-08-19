%optimzie number of clusters
%higher criterior value number is better
function optimize_num_clusters(ALLEEG)
dipXyz = [];
for subjIdx = 1:length(ALLEEG)
 
    % Obtain xyz, dip moment, maxProj channel xyz.   
    xyz = zeros(length(ALLEEG(subjIdx).dipfit.model),3);
    for modelIdx = 1:length(ALLEEG(subjIdx).dipfit.model)
 
        % Choose the larger dipole if symmetrical.
        currentXyz = ALLEEG(subjIdx).dipfit.model(modelIdx).posxyz;
        currentMom = ALLEEG(subjIdx).dipfit.model(modelIdx).momxyz; % nAmm.
        if size(currentMom,1) == 2
            [~,largerOneIdx] = max([norm(currentMom(1,:)) norm(currentMom(2,:))]);
            currentXyz = ALLEEG(subjIdx).dipfit.model(modelIdx).posxyz(largerOneIdx,:);
        end
        if ~isempty(currentXyz)
        xyz(modelIdx,:) = currentXyz;
        end
    end
    dipXyz = [dipXyz; xyz];
end
 
 
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Optimize the number of clusters between the range 10-30. %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Use Matlab function evalclusters().
kmeansClusters = [];
for clustIdx = 10:30
    kmeansClusters(:,clustIdx) = kmeans(dipXyz, clustIdx, 'emptyaction', 'singleton', 'maxiter', 10000, 'replicate', 100);
end
 
kmeansClusters = kmeansClusters(:,10:30);
eva1 = evalclusters(dipXyz, kmeansClusters, 'CalinskiHarabasz');
eva2 = evalclusters(dipXyz, kmeansClusters, 'Silhouette');
%eva3 = evalclusters(dipXyz, kmeansClusters, 'gap', ); % Slow and not consistent value.
eva4 = evalclusters(dipXyz, kmeansClusters, 'DaviesBouldin');
 
figure
subplot(1,3,1)
plot(eva1); title('CalinskiHarabasz');
subplot(1,3,2)
plot(eva2); title('Silhouette');
subplot(1,3,3)
plot(eva4); title('DaviesBouldin');
end