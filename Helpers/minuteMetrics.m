function [row, blk] = minuteMetrics(cfg, k)

% First we read the recording and count how many samples land on each pair of
% I and Q bytes. Each sample gets one index number, since 144 million samples
% are too many to count pair by pair.

lut = dumpLUT();  lut2 = lut.^2;
name = cfg.names{k};

[bI, bQ] = readUC8(cfg.files{k}, 1, cfg.nSamples);
N = numel(bI);

idx = uint32(bI) * 256 + uint32(bQ) + 1;
H = reshape(accumarray(idx, 1, [65536 1]), 256, 256)';

% Then we find the I and Q means and run every estimator on the whole
% recording.

v = (0:255)';
muI = sum(sum(H, 2) .* v) / N;  muQ = sum(sum(H, 1)' .* v) / N;
est = allEstimators(H);

% Next we get dump1090's numbers for the recording: its reported noise and its
% counts.

s = runDump1090(cfg.files{k}, 'stats');

% Here we turn every sample into dump1090's signal power and keep a running
% total, so the power inside any stretch of samples is one subtraction.

p = single(lut2(idx));
cs = [0; cumsum(double(p))];

totPow = cs(end);
totalDb = 10 * log10(totPow / N / 65535^2);

% Then we rebuild dump1090's noise number the way dump1090 does it: the total
% power minus the data part of each decoded Mode S message.

T = loadDecoded(name);
isS = T.kind ~= "modeac";
bits = 56 + 56 * (T.kind == "long");

a = T.sample_start + 1 + cfg.preambleSamples;
b = min(a + floor(bits * 12 / 5) - 1, N);

sigS = sum(cs(b(isS) + 1) - cs(a(isS)));
noiseRebuilt = 10 * log10((totPow - sigS) / N / 65535^2);

% Next we mark every sample inside any decoded message (Mode S or Mode A/C, the
% whole message) and run the estimators again with those samples left out.

mark = accumarray([T.sample_start + 1; min(T.sample_end, N) + 1], ...
                  [ones(height(T), 1); -ones(height(T), 1)], [N + 1 1]);
keep = cumsum(mark(1:N)) == 0;

Hm = reshape(accumarray(idx(keep), 1, [65536 1]), 256, 256)';
estM = allEstimators(Hm);

% Here we find the model background: the power of a rounded bell curve at the
% cell-fraction sigma, through dump1090's table.

pI = quantModel(muI, est(6));  pQ = quantModel(muQ, est(6));
bgDb = 10 * log10(sum(sum((pI * pQ') .* lut2)) / 65535^2);

% Then we do the quietest-window rule: the quietest 20 us window (48 samples)
% in each 1 ms stretch, then the middle value over the minute.

nStr = floor(N / 2400);
W = reshape(mean(reshape(p(1:nStr * 2400), 48, []), 1), 50, nStr);
qwFull = 10 * log10(median(min(W, [], 1)) / 65535^2);

% We do it a second time, skipping every window that touches a decoded
% message.

okW = reshape(all(reshape(keep(1:nStr * 2400), 48, []), 1), 50, nStr);
W(~okW) = Inf;

mins = min(W, [], 1);
qwMasked = 10 * log10(median(mins(isfinite(mins))) / 65535^2);

% Next we count the clipped samples (I or Q at 0 or 255), how many of them sit
% inside messages, and the loudest sample.

clip = bI == 0 | bI == 255 | bQ == 0 | bQ == 255;
nClip = sum(clip);
nClipInMsg = sum(clip & ~keep);

peakDb = 10 * log10(double(max(p)) / 65535^2);

% Then we start an if statement that applies rule R1 on control recordings:
% every sample with more than 25 times the average background power, and 24
% samples on each side of it, is left out, since those are pulses, not
% background.

kr1 = true(N, 1);

if ~cfg.is1090(k)
    thr2 = 50 * est(6)^2;
    hit = (single(bI) - muI).^2 + (single(bQ) - muQ).^2 > thr2;
    kr1 = movmax(uint8(hit), [24 24]) == 0;
end

% Here we run the estimators and the total power again with R1's samples left
% out.

Hr = reshape(accumarray(idx(kr1), 1, [65536 1]), 256, 256)';
estR = allEstimators(Hr);
totalDbR1 = 10 * log10(sum(double(p(kr1))) / sum(kr1) / 65535^2);

% Next we find the cell-fraction sigma in each one-second block (with R1 on
% controls), which rules R3 and R5 use.

L = 2.4e6;  nB = floor(N / L);
inner = (bI == 127 | bI == 128) & (bQ == 127 | bQ == 128);

kk = reshape(kr1(1:nB * L), L, nB);
nKeep = sum(kk, 1);

Pb = sum(reshape(inner(1:nB * L), L, nB) & kk, 1) ./ nKeep;
mIb = sum(double(reshape(bI(1:nB * L), L, nB)) .* kk, 1) ./ nKeep;
mQb = sum(double(reshape(bQ(1:nB * L), L, nB)) .* kk, 1) ./ nKeep;

sb = arrayfun(@(j) sigmaFromCellDC(Pb(j), mIb(j), mQb(j)), 1:nB);

% Then we start an if statement that, on controls only, measures how alike
% each byte is to the 1, 2 and 3 bytes after it, which the twins copy.

acf = nan(1, 3);

if ~cfg.is1090(k)
    x = double(bI) - muI;
    acf = arrayfun(@(g) mean(x(1:end-g) .* x(1+g:end)), 1:3) / mean(x.^2);
end

% Lastly, we put everything for this recording in one row, and the one-second
% values in a table of their own.

row = table(string(name), cfg.session(k), cfg.day(k), cfg.slot(k), cfg.rec(k), ...
    string(cfg.role(k)), cfg.freqHz(k), string(cfg.startUtc(k)), N, muI, muQ, ...
    100 * sum(sum(H(128:129, 128:129))) / N, est(6), est(8), est(1), ...
    estM(6), estM(8), estM(1), estR(6), estR(8), 100 * mean(~kr1), totalDb, totalDbR1, ...
    bgDb, s.noiseDbfs, noiseRebuilt, s.preambles, s.accepted, s.modeac, s.badFormat, ...
    sum(isS), sum(~isS), 100 * mean(~keep), qwFull, qwMasked, nClip, nClipInMsg, peakDb, ...
    min(sb), max(sb), 20 * log10(max(sb) / min(sb)), acf(1), acf(2), acf(3), ...
    'VariableNames', {'name', 'session', 'day', 'slot', 'rec', 'role', 'freqHz', 'startUtc', ...
    'nSamples', 'muI', 'muQ', 'cellPct', 'sigDC', 'sigCF', 'sigMP', 'sigDCmsk', 'sigCFmsk', ...
    'sigMPmsk', 'sigDCr1', 'sigCFr1', 'r1MaskPct', 'totalDb', 'totalDbR1', 'bgDb', ...
    'noisePrinted', 'noiseRebuilt', 'preambles', 'accepted', 'modeac', 'badFormat', ...
    'nModeS', 'nModeAC', 'msgCoverPct', 'qwFullDb', 'qwMaskedDb', 'nClip', 'nClipInMsg', ...
    'peakDb', 'blkSigMin', 'blkSigMax', 'driftDb', 'acf1', 'acf2', 'acf3'});

blk = table(repmat(string(name), nB, 1), repmat(cfg.session(k), nB, 1), ...
    repmat(string(cfg.role(k)), nB, 1), (1:nB)', sb', ...
    'VariableNames', {'name', 'session', 'role', 'block', 'sigDC'});

end

function T = loadDecoded(name)

% Here we read the table of decoded messages, or make an empty one if dump1090
% found nothing.

try
    T = readDecoded(name);
catch
    T = table();
end

if isempty(T) || height(T) == 0
    T = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
              'VariableNames', {'kind', 'sample_start', 'sample_end', 'n_samples'});
end

T.kind = string(T.kind);

end
