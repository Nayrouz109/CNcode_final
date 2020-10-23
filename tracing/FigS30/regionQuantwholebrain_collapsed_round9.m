
clear all
close all

%% load annotation files
% Regionsfull=nrrdread('/home/justus/Documents/justus_synology/justus/atlasfiles/horizontalsections/annotation_25_newcaphorizontal.nrrd');
Regionsfull=nrrdread('A:/justus/atlasfiles/horizontalsections/annotation_25_newcaphorizontal.nrrd');

annotated = readtable('../Ilastik_adipoclear_oct2019/annotation_info_0118_1327_justusedits.csv');
sz = size(Regionsfull);

%% collapse regions according to annotation table.
for i = 1:height(annotated)
    a = str2double(strsplit(annotated.structure_id_path{i},'/'));
    pathId{i} = a(~isnan(a));
end

%combineids = a list of region ids that have all children collapsed
%for the "full" annotation file, only 73 and 1009 are collapsed
%for the "collapsed" annotation file, see the 0108_1327.csv
combineids = annotated.id(logical(annotated.collapse_logical));
regions=Regionsfull;
for i = 1:numel(pathId)
    if any(ismember(pathId{i},combineids))
        
        tmp=pathId{i}(ismember(pathId{i},combineids)); 
        
        regions(regions == annotated.id(i)) = tmp(end); %this allows to include areas like nucleus of darkschewitsch and fields of forrel that are embedded within their parent strucutre.
        i
    end
end

annotated_collapsed=annotated(annotated.collapse_logical==1,:);


%% loop over all brains
DCNnames={'ZI','Ret'};

for d=1:numel(DCNnames)

% get axon directories

datadir=['A:/justus/iDisco/round9/',DCNnames{d}];
brains = dir([datadir,'/brain*']);
for i = 1:size(brains,1)
    datafolder{i} = [datadir,'/',brains(i).name,'/transformix_output_seg-TI/'];
end



% load brain image, and save intensity values of pixels in each annotation
%region 
% the midline is at 177 in cropped7_525
PixelbyRegionR = cell(height(annotated),size(brains,1));
PixelbyRegionL = cell(height(annotated),size(brains,1));
H=height(annotated);
    P=[];

for j = 1:size(brains,1)
%     for j=1
    P(j).s = imfinfo([datafolder{j},'result_fixed.tif']);
    P(j).rawdataL = uint16(zeros(P(j).s(1).Height,177,numel(P(j).s)));
    P(j).rawdataR = uint16(zeros(P(j).s(1).Height,177,numel(P(j).s)));

    for i = 1:numel(P(j).s) %read in only up to midline!
        P(j).tmp=imread([datafolder{j},'result_fixed.tif'],i);
        P(j).rawdataL(:,:,i) = P(j).tmp(:,1:177);
        P(j).rawdataR(:,:,i) = P(j).tmp(:,178:end);
        P(j).rawdatafull(:,:,i) = P(j).tmp;
    end

%    for i = 1:H
    %        PixelbyRegionL{i,j} = P(j).rawdataL(regions(:,1:177,:) == annotated.id(i)); %each saves intensity value for each pixel in a region
   %         PixelbyRegionR{i,j} = P(j).rawdataR(regions(:,178:end,:) == annotated.id(i)); %each saves intensity value for each pixel in a region
  %  end
 %   clear('P(j).rawdataL','P(j).rawdataR');
end
save(['round9_rawdata',DCNnames{d},'.mat'],'P','regions','Regionsfull','annotated','-v7.3');

end


%% calculate region by region axon innervations - normalized and not-normalized
%threshold data and calculate density
load('round9_rawdataZI.mat')


brains=ones(numel(P),1);
PixelbyRegionR = cell(height(annotated),size(brains,1));
PixelbyRegionL = cell(height(annotated),size(brains,1));
H=height(annotated);


intensitythreshold=10000;

for j = 1:size(brains,1)
    j
    for i = 1:H
            PixelbyRegionL{i,j} = P(j).rawdataL(regions(:,1:177,:) == annotated.id(i)); %each saves intensity value for each pixel in a region
            PixelbyRegionR{i,j} = P(j).rawdataR(regions(:,178:end,:) == annotated.id(i)); %each saves intensity value for each pixel in a region
    end
end






for j = 1:size(brains,1)
    
    %first normalize by overall number of axon pixels per brain
    totalaxons=sum(sum(sum(P(j).rawdatafull>intensitythreshold)));
    
for i = 1:length(PixelbyRegionL)
    RegionalDensityL(i,j) = sum(PixelbyRegionL{i,j}>intensitythreshold)/numel(PixelbyRegionL{i,j}); %counts # of pixels above 8000 and divides by total number of pixels in that region
    RegionalDensityR(i,j) = sum(PixelbyRegionR{i,j}>intensitythreshold)/numel(PixelbyRegionR{i,j}); %counts # of pixels above 8000 and divides by total number of pixels in that region

end
end

%now normalize by overall brain fluorescence levels.
for j = 1:size(brains,1)
    NormalizedRegionalDensityL(:,j) = RegionalDensityL(:,j)/nansum(RegionalDensityL(:,j)+RegionalDensityR(:,j));
    NormalizedRegionalDensityR(:,j) = RegionalDensityR(:,j)/nansum(RegionalDensityL(:,j)+RegionalDensityR(:,j));
end


%%%%%%alternatively do not normalize by region size

clear AxonsByRegion NormalizedInnervation
for j=1:size(brains,1)
    for i=1:length(PixelbyRegionL)
        AxonsByRegionL(i,j) = sum(PixelbyRegionL{i,j}>intensitythreshold);
        AxonsByRegionR(i,j) = sum(PixelbyRegionR{i,j}>intensitythreshold);
    end
end

for j=1:size(brains,1)
    NormalizedInnervationL(:,j) = AxonsByRegionL(:,j)/nansum(AxonsByRegionL(:,j)+AxonsByRegionR(:,j));
    NormalizedInnervationR(:,j) = AxonsByRegionR(:,j)/nansum(AxonsByRegionL(:,j)+AxonsByRegionR(:,j));
end


% save
mkdir('Matlab_output_collapsed_ZI');
save((['Matlab_output_collapsed_ZI/NormalizedRegionalDensity.mat']),...
    'RegionalDensityL','RegionalDensityR',...
    'NormalizedRegionalDensityL','NormalizedRegionalDensityR',...
    'AxonsByRegionL','AxonsByRegionR',...
    'NormalizedInnervationL','NormalizedInnervationR',...
    'brains','annotated','PixelbyRegionL','PixelbyRegionR');%save output
