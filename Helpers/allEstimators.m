function [est, names] = allEstimators(H)

% First we set up the estimator names and the I and Q byte counts and means.

names = {'meanPower', 'sheppard', 'medianMag', 'mad', 'p40', ...
         'cellDC', 'cellCentred', 'centralFit'};
est = nan(1, numel(names));

lut = dumpLUT();
N = sum(H(:));
v = (0:255)';

hI = sum(H, 2);  hQ = sum(H, 1)';
muI = sum(hI .* v) / N;  muQ = sum(hQ .* v) / N;

% meanPower is the noise dump1090 reports, turned into a sigma.

P = sum(H(:) .* lut(:).^2) / N / 65535^2;
est(1) = 128 * sqrt(P / 2);

% sheppard is the spread of the bytes minus the small amount that rounding adds.

vI = sum(hI .* (v - muI).^2) / N;  vQ = sum(hQ .* (v - muQ).^2) / N;
est(2) = sqrt(max((vI + vQ) / 2 - 1/12, 0));

% medianMag comes from the middle value of the signal strength.

[gI, gQ] = ndgrid(v, v);
r = sqrt((gI - muI).^2 + (gQ - muQ).^2);
est(3) = weightedMedian(r(:), H(:)) / sqrt(2 * log(2));

% mad comes from the typical distance of each byte from its middle value.

mI = weightedMedian(v, hI);  mQ = weightedMedian(v, hQ);
madI = weightedMedian(abs(v - mI), hI);  madQ = weightedMedian(abs(v - mQ), hQ);
est(4) = 1.4826 * sqrt((madI^2 + madQ^2) / 2);

% p40 comes from the 40th percentile that dump1090's automatic gain uses.

[lev, ~, g] = unique(lut(:));
cnt = accumarray(g, H(:));
k = find(cumsum(cnt) > floor(N * 0.40), 1);
est(5) = lev(k) / 65535 * 128 / sqrt(-2 * log(0.6));

% cellDC comes from the share of samples in the 4 center squares, with the
% measured center.

Pc = sum(sum(H(128:129, 128:129))) / N;
est(6) = sigmaFromCellDC(Pc, muI, muQ);

% cellCentred is the same but assumes the center is exactly 127.5.

if exist('cellSigma', 'file') == 2
    est(7) = cellSigma(Pc);
end

% Lastly, centralFit fits a bell curve to just the middle bytes of I and Q.

est(8) = sqrt((centralFit(hI, muI)^2 + centralFit(hQ, muQ)^2) / 2);

end

function m = weightedMedian(x, w)

% Here we sort the values and find where the running count passes half.

[xs, o] = sort(x(:));
c = cumsum(w(o));
m = xs(find(c >= c(end) / 2, 1));

end

function s = centralFit(h, mu0)

% Here we make a first guess at sigma and set a window around the center.

Phi = @(z) 0.5 * erfc(-z / sqrt(2));
v = (0:255)';
c = cumsum(h) / sum(h);

q1 = v(find(c >= 0.25, 1));  q3 = v(find(c >= 0.75, 1));
s = max((q3 - q1) / 1.349, 0.3);

mu = mu0;
W = max(1.5, 1.5 * s);

% Then we start a for loop that fits the center and sigma to the bytes in the
% window, and repeats with a new window.

for it = 1:6
    in = abs(v - mu0) <= W;
    b = v(in);  n = h(in);

    nll = @(th) -sum(n .* log(max(binP(b, th(1), exp(th(2)), Phi), 1e-300))) ...
                + 1e6 * (th(2) > log(200));
    th = fminsearch(nll, [mu, log(s)], optimset('TolX', 1e-7, 'TolFun', 1e-9, 'Display', 'off'));
    mu = th(1);  s = exp(th(2));

    Wnew = max(1.5, 1.5 * s);
    if abs(Wnew - W) < 0.5, break; end
    W = Wnew;

end

end

function p = binP(b, mu, s, Phi)

% Here we get the chance of each byte, given that it landed inside the window.

p = Phi((b + 0.5 - mu) / s) - Phi((b - 0.5 - mu) / s);
p = p / sum(p);

end
