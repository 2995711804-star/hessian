function Io = project_rows(I,X,clip)
[H,~] = size(I); Io = zeros(size(I));
for r=1:H
    y = I(r,:).'; m = (y>clip(1)) & (y<clip(2));
    if nnz(m)<16, b = X\y; else, b = X(m,:)\y(m); end
    Io(r,:) = (X*b).';
end
end
