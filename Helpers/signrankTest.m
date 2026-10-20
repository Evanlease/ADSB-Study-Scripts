function [p, Wplus, n] = signrankTest(d)

% First we drop exact zeros, since they have no sign, and rank the sizes of
% what's left.

d = d(:);
d = d(d ~= 0 & ~isnan(d));
n = numel(d);
if n == 0, p = NaN; Wplus = NaN; return; end

r = rankAvg(abs(d));
Wplus = sum(r(d > 0));

% Then we double the ranks so tied averages (like 2.5) become whole numbers.

r2 = round(2 * r);
total = sum(r2);
dist = zeros(total + 1, 1);
dist(1) = 1;

% Next we start a for loop that builds the exact chance of every possible
% total, adding one rank at a time with a random sign.

for j = 1:n
    shifted = [zeros(r2(j), 1); dist(1:end - r2(j))];
    dist = 0.5 * dist + 0.5 * shifted;
end

% Lastly, the two-sided p-value is twice the smaller tail at our real total.

w = round(2 * Wplus);
lower = sum(dist(1:w + 1));
upper = sum(dist(w + 1:end));
p = min(1, 2 * min(lower, upper));

end
