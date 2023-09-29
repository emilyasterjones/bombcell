function unitType = eaj_getQualityUnitType(param, qMetric)
% JF, Classify units into good/mua/noise/non-somatic 
% ------
% Inputs
% ------
% 
% ------
% Outputs
% ------
% % EAJ update 20 Sept 2023: built new filter step

unitType = nan(length(qMetric.percentageSpikesMissing_gaussian), 1);
unitType(qMetric.nTroughs > param.maxNTroughs | ...
    qMetric.waveformDuration_peakTrough > param.maxWvDuration | ...
    qMetric.percentageSpikesMissing_gaussian > param.maxPercSpikesMissing |...
    (qMetric.spatialDecaySlope >= param.minSpatialDecaySlope & ...
    qMetric.ecephys_snr < param.minSNR & ...
    qMetric.ecephys_halfwidth < param.maxHalfwidth)) = 0; % NOISE