function [I1s,I2s,I3s,I4s,stats] = enforce_sinusoid_per_row(I1,I2,I3,I4, P, clip)
[H,W] = size(I1); w = 2*pi/P; x = (0:W-1);
X = [cos(w*x(:)) sin(w*x(:)) ones(W,1)];
I1s = project_rows(I1,X,clip); I2s = project_rows(I2,X,clip);
I3s = project_rows(I3,X,clip); I4s = project_rows(I4,X,clip);
M0  = 0.5*sqrt((I4-I2).^2 + (I1-I3).^2);
M1  = 0.5*sqrt((I4s-I2s).^2 + (I1s-I3s).^2);
stats = struct('M_before_mean',mean(M0(:),'omitnan'),'M_after_mean',mean(M1(:),'omitnan'));
end
