function rawWaveforms = bc_extractRawWaveformsFast(rawFolder, nChannels, nSpikesToExtract, spikeTimes, spikeTemplates, reExtract, verbose, maxChannels)
% JF, Get raw waveforms for all templates
% ------
% Inputs
% ------
% nChannels: number of recorded channels (including sync), (eg 385)
% nSpikesToExtract: number of spikes to extract per template
% spikeTimes: nSpikes × 1 uint64 vector giving each spike time in samples (*not* seconds)
% spikeTemplates: nSpikes × 1 uint32 vector giving the identity of each
%   spike's matched template
% rawFolder: string containing the location of the raw .dat or .bin file
% verbose: boolean, display progress bar or not
% ------
% Outputs
% ------
% rawWaveforms: struct with fields:
%   spkMapMean: nUnits × nTimePoints × nChannels single matrix of
%   mean raw waveforms for each unit and channel
%   peakChan: nUnits x 1 vector of each unit's channel with the maximum
%   amplitude
if nargin<8
    UseMaxChannels = 0;
else
    UseMaxChannels = 1;
end

%% check if waveforms already extracted
% Get binary file name
if iscell(rawFolder)
    rawFolder = fileparts(rawFolder{1});
elseif sum(rawFolder(end-2:end) == '/..') == 3
    rawFolder = fileparts(rawFolder(1:end-3));
end
spikeFile = dir(fullfile(rawFolder, '*.ap.*bin'));
if isempty(spikeFile)
    spikeFile = dir(fullfile(rawFolder, '/*.dat')); %openEphys format
end
if size(spikeFile,1) > 1
   spikeFile = dir(fullfile(rawFolder, '*tcat*.ap.*bin'));
end 

rawWaveformFolder = dir(fullfile(spikeFile.folder, 'rawWaveforms.mat'));

fname = spikeFile.name;
dataTypeNBytes = numel(typecast(cast(0, 'uint16'), 'uint8'));

if any(strfind(fname,'cbin'))
    disp('This is compressed data. Use Python integration... If you don''t have that option please uncompress data first')
    UsePython = 1;
    % Read original bytes
    meta = ReadMeta2(spikeFile.folder);
    n_samples = round(str2num(meta.fileSizeBytes)/dataTypeNBytes/nChannels);
    SR = meta.imSampRate;
else
    UsePython = 0;
end

d = dir(fullfile(rawFolder, fname));


if ~isempty(rawWaveformFolder) && reExtract == 0
    load(fullfile(spikeFile.folder, 'rawWaveforms.mat'));
else

    %% Intitialize

    if ~UsePython
        fid = fopen(fullfile(spikeFile.folder, fname), 'r');
    end
    spikeWidth = 82;
    halfWidth = spikeWidth / 2;
    clustInds = unique(spikeTemplates);
    nClust = numel(clustInds);

%     try % memMap to check you have correct number of channels, if not remove one channel 
%         n_samples = spikeFile.bytes/ (nChannels * dataTypeNBytes);
%         memmapfile(fullfile(spikeFile.folder, fname),'Format',{'int16',[nChannels,n_samples],'data'});
%     catch
%         disp(['Guessing correct number of channels is ', num2str(nChannels-1)])
%         nChannels = nChannels - 1;
%     end
    
    %% Interate over spike clusters and find all the data associated with them
    rawWaveforms = struct;
    allSpikeTimes = spikeTimes;
    disp('Extracting raw waveforms ...')
    % array
    for iCluster = 1:nClust
        disp(['Cluster ' num2str(iCluster) '/' num2str(nClust)])
        spikeIndices = allSpikeTimes(spikeTemplates == clustInds(iCluster)).*str2num(SR); %Shouldn't this be in byte??
        if numel(spikeIndices) >= nSpikesToExtract % extract a random subset of regularly spaced raw waveforms
            spksubi = round(linspace(1, numel(spikeIndices), nSpikesToExtract))';
            spikeIndices = spikeIndices(spksubi);
        end
        nSpikesEctractHere = numel(spikeIndices);
        if nChannels == 385
            spikeMap = nan(nChannels-1, spikeWidth, nSpikesEctractHere,'single');
        else
            spikeMap = nan(nChannels, spikeWidth, nSpikesEctractHere,'single');
        end
        for iSpike = 1:nSpikesEctractHere
            thisSpikeIdx = spikeIndices(iSpike);
            if thisSpikeIdx > halfWidth && (thisSpikeIdx + halfWidth) * dataTypeNBytes < d.bytes % check that it's not out of bounds
                if UsePython
                    stidx = (thisSpikeIdx - halfWidth);
                    endidx = (thisSpikeIdx + halfWidth);
                    try
                        data = nan(nChannels,spikeWidth,'single');
                        if UseMaxChannels
                            channels2take = maxChannels(iCluster)-5:maxChannels(iCluster)+5;
                            channels2take(channels2take<1|channels2take>nChannels-1) = [];
                        else
                            channels2take = 1:nChannels;
                        end
                        parfor chid=channels2take
                            tmpdata = pyrunfile("Ephys_Reader_FromMatlab.py","chunk",...
                                datapath = strrep(fullfile(spikeFile.folder,fname),'\','/'),start_time=stidx,end_time=endidx,channel=chid-1); %0-indexed!!
                            data(chid,:)=tmpdata;
                        end
                    catch ME
                        disp(ME)
                        disp('Make sure to use MATLAB>2022a and compatible python version, in an environment that has the modules phylib, pathlib, and matlab installed')
                        disp('e.g. pyversion("C:\Users\EnnyB\anaconda3\envs\phy\pythonw.exe")')
                        disp('Also make suer you input the path in a python-compatible way!')
                    end
                else
                    byteIdx = int64(((thisSpikeIdx - halfWidth) * nChannels) * dataTypeNBytes); % int64 to prevent overflow on crappy windows machines that are incredibly inferior to linux
                    fseek(fid, byteIdx, 'bof'); % from beginning of file
                    data = fread(fid, [nChannels, spikeWidth], 'int16=>int16'); % read individual waveform from binary file
                    frewind(fid);
                end
                if size(data, 2) == spikeWidth && nChannels == 385
                    spikeMap(:, :, iSpike) = data(1:nChannels-1, :, :); %remove sync channel
                elseif size(data, 2) == spikeWidth
                    spikeMap(:, :, iSpike) = data(1:nChannels, :, :);
                end
            end
        end
        spikeMapMean = nanmean(spikeMap, 3);

        rawWaveforms(iCluster).spkMapMean = spikeMapMean - mean(spikeMapMean(:, 1:10), 2);

        spkMapMean_sm = smoothdata(spikeMapMean, 1, 'gaussian', 5);

        [~, rawWaveforms(iCluster).peakChan] = max(max(abs(spkMapMean_sm), [], 2), [], 1);%QQ buggy sometimes

%         [~, maxChannels] = max(max(abs(templateWaveforms), [], 2), [], 3);
%         close all;
%         
%                 clf;
%                 for iSpike = 1:10
%                     plot(spikeMap(rawWaveforms(iCluster).peakChan, :, iSpike));
%                     hold on;
%                 end
%                 figure()
%                 clf;
%                 plot(rawWaveforms(iCluster).spkMapMean(rawWaveforms(iCluster).peakChan, :));
%                 hold on;
%                 
%                 
%                 figure()
%                 clf;
%                 plot(squeeze(templateWaveforms(uniqueTemplates(iCluster),:,maxChannels(uniqueTemplates(iCluster)))));
%                 hold on;
%                 plot(squeeze(templateWaveforms(uniqueTemplates(iCluster),:,goodChannels(rawWaveforms(iCluster).peakChan))));
                
                
        if (mod(iCluster, 20) == 0 || iCluster == nClust) && verbose
            fprintf(['\n   Extracted ', num2str(iCluster), '/', num2str(nClust), ' raw waveforms']);
            %figure; imagesc(spkMapMean_sm)
            %title(['Unit ID: ', num2str(i)]);
            %colorbar;
        end

    end

    fclose(fid);
    rawWaveformFolder = dir(fullfile(spikeFile.folder, 'rawWaveforms.mat'));
    if isempty(rawWaveformFolder) || reExtract
        save(fullfile(spikeFile.folder, 'rawWaveforms.mat'), 'rawWaveforms', '-v7.3');
    end
end
end