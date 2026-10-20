function sigma = sigmaFromCellDC(P, muI, muQ)

% First we write the chance that one byte lands on 127 or 128 for a given sigma
% and center.

Phi = @(z) 0.5 * erfc(-z / sqrt(2));
cellP = @(s, mu) Phi((128.5 - mu) / s) - Phi((126.5 - mu) / s);

% Lastly, we find the sigma that gives the same share of center samples that we
% measured.

f = @(s) cellP(s, muI) * cellP(s, muQ) - P;
sigma = fzero(f, [0.05 200]);

end
