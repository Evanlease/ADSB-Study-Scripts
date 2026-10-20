function T = readDecoded(name)

% First we find the table of decoded messages for this capture.

cfg = expConfig();
f = fullfile(cfg.decDir, [name '.csv']);

% Then we read it, with kind and hex as text and the other columns as numbers.

opts = detectImportOptions(f, 'Delimiter', ',');
opts = setvartype(opts, {'kind', 'hex'}, 'string');
opts = setvartype(opts, {'df', 'ts12', 'sample_start', 'sample_end', 'n_samples'}, 'double');
T = readtable(f, opts);

end
