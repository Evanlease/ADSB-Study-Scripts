function [bI, bQ, h] = colorTwin(sigma, N, seed, acfTarget, mu)

% First we default to this receiver's center.

if nargin < 5, mu = 127.397; end

% Then we start a for loop that fits a filter to the target autocorrelation (how
% alike nearby samples are), tests it on a short file, and adjusts, since
% rounding to bytes weakens the match.

rhoG = acfTarget;

for it = 1:6
    h = fitFir(rhoG);
    [tI, ~] = make(h, sigma, 2.4e6, 1, mu);

    x = double(tI) - mean(double(tI));
    got = arrayfun(@(L) mean(x(1:end-L) .* x(1+L:end)), 1:3) / mean(x.^2);
    rhoG = rhoG .* acfTarget ./ got;

end

% Lastly, we build the full twin with the final filter.

h = fitFir(rhoG);
[bI, bQ] = make(h, sigma, N, seed, mu);

end

function h = fitFir(rho)

% Here we search for a 4-number filter that gives the autocorrelation we want.

acf = @(h) [sum(h(1:3) .* h(2:4)), sum(h(1:2) .* h(3:4)), h(1) * h(4)] / sum(h.^2);
h = fminsearch(@(h) sum((acf(h) - rho).^2), [1 rho], ...
               optimset('TolX', 1e-10, 'TolFun', 1e-14, 'MaxFunEvals', 1e4, 'Display', 'off'));
h = h / norm(h);

end

function [bI, bQ] = make(h, sigma, N, seed, mu)

% Here we filter random noise, then scale, round and clip it to bytes.

rng(seed, 'twister');
gI = filter(h, 1, randn(N + 3, 1));  gQ = filter(h, 1, randn(N + 3, 1));
bI = uint8(min(max(round(mu + sigma * gI(4:end)), 0), 255));
bQ = uint8(min(max(round(mu + sigma * gQ(4:end)), 0), 255));

end
