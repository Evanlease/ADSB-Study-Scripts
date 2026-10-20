function ci = bootCI(stat, data, nBoot, seed)

% First we fix the random seed so the interval comes out the same every run.

if nargin < 3, nBoot = 10000; end
if nargin < 4, seed = 2026; end
rng(seed, 'twister');

% Then we start a for loop that resamples whole sessions (rows) with
% replacement and recomputes the statistic each time.

n = size(data, 1);
vals = nan(nBoot, 1);

for b = 1:nBoot
    vals(b) = stat(data(randi(n, n, 1), :));
end

% Lastly, the 95% interval is the 2.5th and 97.5th percentiles of those
% values.

vals = sort(vals(~isnan(vals)));
m = numel(vals);
ci = [vals(max(1, round(0.025 * m))), vals(min(m, round(0.975 * m)))];

end
