function p = quantModel(mu, sigma)

% First we create the bell curve and the edges of each byte's rounding range.

Phi = @(z) 0.5 * erfc(-z / sqrt(2));
edges = ((0:256)' - 0.5 - mu) / sigma;
edges(1) = -Inf;  edges(end) = Inf;

% Lastly, the chance of each byte is the area under the curve between its two
% edges.

p = Phi(edges(2:end)) - Phi(edges(1:end-1));

end
