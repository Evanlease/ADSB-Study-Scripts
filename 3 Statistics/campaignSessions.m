% First we switch to the campaign data, load the table of recordings and the
% table of one-second blocks, and open the summary file.

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();

R = readCampaign(fullfile(cfg.outDir, 'minutes.csv'));
B = readCampaign(fullfile(cfg.outDir, 'blocks.csv'));
isCtl = R.role ~= "1090";

out = fopen(fullfile(cfg.outDir, 'summary.txt'), 'w');
say = @(varargin) fprintf(out, varargin{:});

% Then we check that our rebuilt noise number matches the one dump1090 printed,
% to within its 0.1 dB rounding plus the 0.01 dB that amendment A1 allows.

dev = abs(R.noiseRebuilt - R.noisePrinted);
gateC = dev <= 0.06 + 1e-9;

say('Gate C (rebuilt noise within 0.06 dB of printed, A1): %d of %d minutes pass; %d within 0.05; largest %.3f dB\n', ...
    sum(gateC), height(R), sum(dev <= 0.05 + 1e-9), max(dev));

if ~all(gateC)
    say('  FAILS: %s\n', strjoin(R.name(~gateC), ', '));
end

% Next we apply rule R5. A one-second block is overloaded if its sigma is more
% than 10 dB above the median control recording, and a recording is overloaded
% if 6 or more of its blocks are.

sigRef = median(R.sigDCr1(isCtl));
limit = sigRef * 10^(10 / 20);

[~, loc] = ismember(B.name, R.name);
R.nOverBlk = accumarray(loc, double(B.sigDC > limit), [height(R) 1]);
R.overload = R.nOverBlk >= 6;

say('\nR5: sigma_ref = %.4f LSB, limit = %.4f LSB; overloaded minutes: %d\n', sigRef, limit, sum(R.overload));
say('  %s\n', R.name(R.overload));

% Here we work out each recording's local start time, and its model background
% with the central fit instead of the cell fraction, which sensitivity run S4
% uses.

hh = str2double(extractBetween(R.startUtc, 10, 11)) - 4;
mm = str2double(extractBetween(R.startUtc, 12, 13));
R.localMin = 60 * hh + mm;

lut2 = dumpLUT().^2;
R.bgCFDb = arrayfun(@(j) 10 * log10(sum(sum((quantModel(R.muI(j), R.sigCF(j)) * ...
                   quantModel(R.muQ(j), R.sigCF(j))') .* lut2)) / 65535^2), (1:height(R))');

% Then we pick the headline recordings: everything except session 2 (rule R4)
% and the overloaded recordings.

R.headline = R.session ~= 2 & ~R.overload;
writetable(R, fullfile(cfg.outDir, 'minutes_flagged.csv'));

% Next we build the table of sessions for the headline, and for the four other
% sets of recordings that the sensitivity runs need.

SH = sessionStats(R, R.headline, "DC");
S1 = sessionStats(R, ~R.overload, "DC");
S2 = sessionStats(R, R.session ~= 2, "DC");
S4 = sessionStats(R, R.headline, "CF");

S3 = SH;  S3.inSet(S3.r3Flag) = false;
writetable(SH, fullfile(cfg.outDir, 'sessions.csv'));

% Here we write down which sessions made the headline and which ones rule R3
% flagged.

say('\nHeadline: %d sessions (session 2 out by R4; sessions with no clean control or 1090 minute out)\n', sum(SH.inSet));
say('  sessions out: %s\n', mat2str(SH.session(~SH.inSet)'));
say('  R3 flagged sessions (drift or control disagreement > 1.0 dB): %s\n', mat2str(SH.session(SH.inSet & SH.r3Flag)'));

% Then we report the tests for the headline and for every sensitivity run. S5
% only redoes the declared test, with the model-free gap.

report(say, SH, 'HEADLINE', true);
report(say, S1, 'S1 session 2 included', false);
report(say, S2, 'S2 overloaded minutes included', false);
report(say, S3, 'S3 R3-flagged sessions dropped', false);
report(say, S4, 'S4 centralFit in place of cellDC', false);

t5 = SH(SH.inSet, :);
[rho5, p5, ci5] = spearmanTest(t5.Gctl, t5.rate);
say('\nS5 T1 with the model-free gap: rho = %+.3f, p = %.4f, 95%% CI [%+.3f, %+.3f], n = %d\n', rho5, p5, ci5, height(t5));

% Next we describe how the floor moved over the week, using every session and
% its controls. The floor is each session's control sigma compared with the
% quietest session's, in dB.

D = sessionStats(R, true(height(R), 1), "DC");
D.F = 20 * log10(D.sigCtl / min(D.sigCtl));

say('\nD1 floor F = 20 log10(sigma_ctl / lowest), all 28 sessions\n');
say('  lowest sigma_ctl %.4f LSB (session %d); median F %.2f dB, IQR %.2f to %.2f, range %.2f to %.2f dB\n', ...
    min(D.sigCtl), D.session(D.sigCtl == min(D.sigCtl)), median(D.F), prctile50(D.F, 25), ...
    prctile50(D.F, 75), min(D.F), max(D.F));
say('  without session 2 and day 6 (sessions 21 to 24): median %.2f, range %.2f to %.2f dB\n', ...
    median(D.F(~ismember(D.session, [2 21 22 23 24]))), min(D.F(~ismember(D.session, [2 21 22 23 24]))), ...
    max(D.F(~ismember(D.session, [2 21 22 23 24]))));

% Here we start a for loop that prints one line per session, and then save the
% floor table.

say('  %4s %4s %5s %6s %7s %7s %6s %6s\n', 'sess', 'day', 'start', 'F dB', 'sigCtl', 'drift', 'disag', 'nOver');

for s = 1:height(D)
    say('  %4d %4d %02d:%02d %6.2f %7.4f %7.2f %6.2f %6d\n', D.session(s), D.day(s), ...
        floor(D.startMin(s) / 60), mod(D.startMin(s), 60), D.F(s), D.sigCtl(s), D.maxDriftDb(s), ...
        D.ctlDisagreeDb(s), D.nOverMin(s));
end

writetable(D, fullfile(cfg.outDir, 'floor_by_session.csv'));

% Then we start a for loop that records how much rule R1 masked on each control
% frequency, and after it we record the clipping.

for rl = ["ctl_lo", "ctl_hi"]
    x = R.r1MaskPct(R.role == rl);
    say('\nR1 masked %% on %s: median %.4f, max %.4f, minutes with any masking %d of %d', rl, median(x), max(x), sum(x > 0), numel(x));
end

t = R(R.role == "1090", :);
say('\nR2 clipping on 1090 minutes: %d of %d minutes have clipped samples, %d clipped samples in all, %.1f %% of them inside decoded messages\n', ...
    sum(t.nClip > 0), height(t), sum(t.nClip), 100 * sum(t.nClipInMsg) / max(1, sum(t.nClip)));

% Lastly, we start a for loop that lists every overloaded recording beside
% clean recordings made at the same clock time on other days, and then we close
% the summary.

say('\nC3c overloaded minutes\n  %-34s %7s %8s %9s %8s %10s\n', 'minute', 'sigDC', 'accepted', 'gap dB', 'peakDb', 'other days');
clean1090 = R(R.headline & R.role == "1090", :);

for j = find(R.overload)'
    near = clean1090(abs(clean1090.localMin - R.localMin(j)) <= 60 & clean1090.day ~= R.day(j), :);
    say('  %-34s %7.3f %8d %9.2f %8.1f %10.0f\n', R.name(j), R.sigDC(j), R.accepted(j), ...
        R.noiseRebuilt(j) - R.bgDb(j), R.peakDb(j), median(near.accepted));
end

fclose(out);
type(fullfile(cfg.outDir, 'summary.txt'));

function S = sessionStats(R, use, est)

% First we start an if statement that picks the estimator: the cell fraction,
% or the central fit for sensitivity run S4.

if est == "CF"
    sig = R.sigCF;  sigR1 = R.sigCFr1;  bg = R.bgCFDb;  sigM = R.sigCFmsk;
else
    sig = R.sigDC;  sigR1 = R.sigDCr1;  bg = R.bgDb;  sigM = R.sigDCmsk;
end

% Then we start a for loop that goes session by session and keeps only the
% recordings this run uses.

n = max(R.session);
S = table((1:n)', 'VariableNames', {'session'});

for s = 1:n
    all_ = R.session == s;
    c = all_ & R.role ~= "1090" & use;
    t = all_ & R.role == "1090" & use;

    S.day(s) = R.day(find(all_, 1));
    S.startMin(s) = min(R.localMin(all_));
    S.nCtl(s) = sum(c);  S.n1090(s) = sum(t);
    S.inSet(s) = S.nCtl(s) >= 1 && S.n1090(s) >= 1;
    S.nOverMin(s) = sum(R.overload(all_));

    % Here are the floor numbers: the controls' mean sigma, how far they drifted
    % within a minute, and how far apart the two controls are (rule R3).

    S.sigCtl(s) = mean(sigR1(c));
    S.maxDriftDb(s) = max([R.driftDb(c); NaN]);
    lo = c & R.role == "ctl_lo";  hi = c & R.role == "ctl_hi";

    if any(lo) && any(hi)
        S.ctlDisagreeDb(s) = abs(20 * log10(sigR1(lo) / sigR1(hi)));
    else
        S.ctlDisagreeDb(s) = NaN;
    end

    S.r3Flag(s) = S.maxDriftDb(s) > 1.0 || S.ctlDisagreeDb(s) > 1.0;

    % Next is C1: how far the reported noise sits above the model background,
    % on the 1090 recordings and on the controls, and the version with no model.

    S.G(s) = median(R.noiseRebuilt(t) - bg(t));
    S.Z(s) = mean(R.noiseRebuilt(c) - bg(c));
    S.D(s) = S.G(s) - S.Z(s);
    S.Gctl(s) = median(R.noiseRebuilt(t) - 10 * log10(mean(10 .^ (R.totalDbR1(c) / 10))));

    % Then is C2: how much each estimator moves when the decoded messages are
    % taken out, and how far each one reads from the controls.

    S.bDC(s) = median(20 * log10(R.sigDC(t) ./ R.sigDCmsk(t)));
    S.bCF(s) = median(20 * log10(R.sigCF(t) ./ R.sigCFmsk(t)));
    S.bMP(s) = median(20 * log10(R.sigMP(t) ./ R.sigMPmsk(t)));
    S.bQW(s) = median(R.qwFullDb(t) - R.qwMaskedDb(t));

    ref = mean(R.sigDCr1(c));
    S.vDC(s) = median(20 * log10(R.sigDC(t) / ref));
    S.vCF(s) = median(20 * log10(R.sigCF(t) / mean(R.sigCFr1(c))));
    S.vMP(s) = median(20 * log10(R.sigMP(t) / ref));
    S.vQW(s) = median(R.qwFullDb(t)) - 10 * log10(mean(10 .^ (bg(c) / 10)));

    % Lastly, for the declared test, the message rate is the accepted Mode S
    % messages per second, averaged over the session's 1090 recordings.

    S.rate(s) = mean(R.accepted(t)) / 60;

end

end

function report(say, S, label, full)

% First we keep only the sessions in this run's set.

T = S(S.inSet, :);
say('\n==== %s: n = %d sessions\n', label, height(T));

% Then we report C1: the median of D across sessions, its interval, and the
% signed-rank test, then the same for the model-free gap.

pD = signrankTest(T.D);
ci = bootCI(@(x) median(x), T.D);
say('C1  median D = %+.3f dB, 95%% CI [%+.3f, %+.3f], Wilcoxon p = %.2g; median G = %+.3f, median Z = %+.3f\n', ...
    median(T.D), ci, pD, median(T.G), median(T.Z));

ciC = bootCI(@(x) median(x), T.Gctl);
say('    model-free median gap = %+.3f dB, 95%% CI [%+.3f, %+.3f], Wilcoxon p = %.2g\n', ...
    median(T.Gctl), ciC, signrankTest(T.Gctl));

% Next we start a for loop that reports C2 for each estimator: how much it
% moved inside each minute, and how far it read from the controls.

names = ["cellDC", "centralFit", "meanPower", "quietest window"];
bcol = ["bDC", "bCF", "bMP", "bQW"];  vcol = ["vDC", "vCF", "vMP", "vQW"];

for e = 1:4
    x = T.(bcol(e));  y = T.(vcol(e));
    ciB = bootCI(@(z) median(z), x);
    say('C2  %-15s within-minute median %+.3f dB [%+.3f, %+.3f], p = %.2g; vs controls median %+.3f dB, range %+.2f to %+.2f\n', ...
        names(e), median(x), ciB, signrankTest(x), median(y), min(y), max(y));
end

say('    control disagreement: median %.2f dB, max %.2f dB\n', median(T.ctlDisagreeDb, 'omitnan'), max(T.ctlDisagreeDb));

% Lastly, we report the declared test: Spearman's rho between the gap and the
% message rate, with its p-value and interval.

[rho, p, ciR] = spearmanTest(T.G, T.rate);
say('T1  rho(G, rate) = %+.3f, permutation p = %.4f, 95%% CI [%+.3f, %+.3f], n = %d\n', rho, p, ciR, height(T));

if full
    say('    rate range %.1f to %.1f msg/s; G range %+.2f to %+.2f dB\n', min(T.rate), max(T.rate), min(T.G), max(T.G));
end

end

function [rho, p, ci] = spearmanTest(x, y)

% First we get rho and get the ranks ready.

rho = spearmanRho(x, y);
rng(19, 'twister');

rx = rankAvg(x);  rx = rx - mean(rx);
ry = rankAvg(y);  ry = ry - mean(ry);
den = sqrt(sum(rx.^2) * sum(ry.^2));

% Then we start a for loop that shuffles y against x 100,000 times, in 10
% batches, and counts how often the shuffled rho is at least as far from zero
% as the real one.

n = numel(x);  hits = 0;  nPerm = 100000;

for k = 1:10
    [~, P] = sort(rand(n, nPerm / 10));
    r = (rx' * ry(P)) / den;
    hits = hits + sum(abs(r) >= abs(rho) - 1e-12);
end

p = (hits + 1) / (nPerm + 1);

% Lastly, we get a bootstrap interval for rho, resampling sessions as pairs.

ci = bootCI(@(z) spearmanRho(z(:, 1), z(:, 2)), [x(:), y(:)]);

end

function q = prctile50(x, pct)

% Here we take a percentile by sorting the values and reading between them.

x = sort(x(~isnan(x)));
q = interp1(linspace(0, 100, numel(x)), x, pct);

end
