function r = rankAvg(x)

% First we sort the values and give them ranks 1, 2, 3, and so on.

x = x(:);
[xs, o] = sort(x);
r = zeros(size(x));
r(o) = 1:numel(x);

% Then we start an if statement that gives tied values the average of the
% ranks they share.

[u, ~, g] = unique(xs);

if numel(u) < numel(xs)
    avg = accumarray(g, (1:numel(xs))') ./ accumarray(g, 1);
    r(o) = avg(g);
end

end
