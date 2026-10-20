% First we switch to the campaign data, keep the 25 headline sessions, and
% count how many fall on each day. This whole script is a check added after the
% results were in (amendment A4): do they hold if sessions on the same day are
% alike?

setenv('PAPERA_MODE', 'campaign');
cfg = expConfig();

S = readCampaign(fullfile(cfg.outDir, 'sessions.csv'));
T = S(S.inSet, :);

days = unique(T.day);
nD = numel(days);
perDay = arrayfun(@(d) sum(T.day == d), days);

% Then we open the output file and write what we're checking.

out = fopen(fullfile(cfg.outDir, 'day_sensitivity.txt'), 'w');
say = @(varargin) fprintf(out, varargin{:});

say('Day-level dependence check (amendment A4, post hoc)\n');
say('n = %d headline sessions on %d days; sessions per day: %s\n', height(T), nD, mat2str(perDay'));

% Next we list every statistic we check, each with a small function that
% computes it from a table of sessions.

names = ["C1 median D", "C1 model-free median gap", "T1 rho(G, rate)", "S5 rho(Gctl, rate)", ...
         "C2 cellDC within-minute", "C2 centralFit within-minute", "C2 meanPower within-minute", ...
         "C2 quietest window within-minute"];
funs = {@(X) median(X.D), @(X) median(X.Gctl), @(X) spearmanRho(X.G, X.rate), ...
        @(X) spearmanRho(X.Gctl, X.rate), @(X) median(X.bDC), @(X) median(X.bCF), ...
        @(X) median(X.bMP), @(X) median(X.bQW)};

% Then we start a for loop that gets each statistic with two intervals: the
% session bootstrap from the paper (to check we get the same one), and a day
% bootstrap, where whole days are drawn instead of sessions.

say('\n%-34s %9s   %-20s   %-20s\n', 'statistic', 'value', 'session bootstrap', 'day bootstrap');
rows = cell(numel(funs), 1);

for j = 1:numel(funs)
    est = funs{j}(T);
    ciS = bootCI(@(ix) funs{j}(T(ix, :)), (1:height(T))');
    ciD = dayBootCI(funs{j}, T, days);

    say('%-34s %+9.3f   [%+7.3f, %+7.3f]   [%+7.3f, %+7.3f]\n', names(j), est, ciS, ciD);
    rows{j} = table(names(j), est, ciS(1), ciS(2), ciD(1), ciD(2), 'VariableNames', ...
        {'statistic', 'value', 'sessLo', 'sessHi', 'dayLo', 'dayHi'});

end

writetable(vertcat(rows{:}), fullfile(cfg.outDir, 'day_sensitivity.csv'));

% Next we redo the declared test with the message rates shuffled only among
% sessions from the same day, so a difference between whole days can't drive
% the p-value. The all-sessions version is run again beside it for comparison.

[rho, pAll] = permTest(T.G, T.rate, ones(height(T), 1));
[~, pDay] = permTest(T.G, T.rate, T.day);
[rho5, pAll5] = permTest(T.Gctl, T.rate, ones(height(T), 1));
[~, pDay5] = permTest(T.Gctl, T.rate, T.day);
nWithin = prod(factorial(perDay));

say('\nT1 rho(G, rate) = %+.3f: permutation p, all sessions shuffled = %.5f; shuffled within days = %.5f\n', rho, pAll, pDay);
say('S5 rho(Gctl, rate) = %+.3f: permutation p, all sessions shuffled = %.5f; shuffled within days = %.5f\n', rho5, pAll5, pDay5);
say('   (100,000 random shuffles each; %d distinct within-day arrangements exist)\n', nWithin);

% Lastly, we squash each day down to the middle value of its sessions and run
% the signed-rank test on the seven day values, which treats days, not
% sessions, as the separate units.

dayD = arrayfun(@(d) median(T.D(T.day == d)), days);
dayC = arrayfun(@(d) median(T.Gctl(T.day == d)), days);

say('\nC1 by day: day medians of D = %s dB\n', mat2str(round(dayD', 3)));
say('   signed-rank on %d day medians: p = %.4f (median %+.3f dB)\n', nD, signrankTest(dayD), median(dayD));
say('   model-free day medians = %s dB, signed-rank p = %.4f\n', mat2str(round(dayC', 3)), signrankTest(dayC));

fclose(out);
type(fullfile(cfg.outDir, 'day_sensitivity.txt'));

function ci = dayBootCI(fun, T, days)

% First we start a for loop that draws seven days with replacement 10,000
% times, keeps every session from each day drawn (a day drawn twice counts
% twice), and recomputes the statistic.

rng(2026, 'twister');
nBoot = 10000;  nD = numel(days);
vals = nan(nBoot, 1);

for b = 1:nBoot
    pick = days(randi(nD, nD, 1));
    ix = cell2mat(arrayfun(@(d) find(T.day == d), pick, 'UniformOutput', false));
    vals(b) = fun(T(ix, :));
end

% Lastly, we take the 2.5th and 97.5th percentiles, the same way bootCI does.

vals = sort(vals(~isnan(vals)));
m = numel(vals);
ci = [vals(max(1, round(0.025 * m))), vals(min(m, round(0.975 * m)))];

end

function [rho, p] = permTest(x, y, grp)

% First we get rho from the ranks of x and y.

rx = rankAvg(x);  rx = rx - mean(rx);
ry = rankAvg(y);  ry = ry - mean(ry);
den = sqrt(sum(rx.^2) * sum(ry.^2));
rho = (rx' * ry) / den;

% Then we get ready to shuffle the ranks of y 100,000 times and count how
% often the shuffled rho is at least as far from zero as the real one.

rng(19, 'twister');
g = unique(grp);
nPerm = 100000;  hits = 0;

% Next we start an if statement. With one group, we use the same shuffles as
% campaignSessions, so the p-value matches the paper.

if numel(g) == 1
    n = numel(x);

    for k = 1:10
        [~, P] = sort(rand(n, nPerm / 10));
        hits = hits + sum(abs((rx' * ry(P)) / den) >= abs(rho) - 1e-12);
    end

% With days as the groups, each session's rate can only trade places with
% another session from the same day.

else
    idx = arrayfun(@(v) find(grp == v), g, 'UniformOutput', false);

    for k = 1:nPerm
        ryp = ry;

        for j = 1:numel(idx)
            ryp(idx{j}) = ry(idx{j}(randperm(numel(idx{j}))));
        end

        hits = hits + (abs(rx' * ryp) / den >= abs(rho) - 1e-12);
    end

end

% Lastly, we turn the count into a p-value.

p = (hits + 1) / (nPerm + 1);

end
