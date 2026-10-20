function rho = spearmanRho(x, y)

% First we rank both sets of values and center the ranks on zero.

rx = rankAvg(x);  ry = rankAvg(y);
rx = rx - mean(rx);  ry = ry - mean(ry);

% Lastly, Spearman's rho is the ordinary correlation of the two sets of ranks.

rho = sum(rx .* ry) / sqrt(sum(rx.^2) * sum(ry.^2));

end
