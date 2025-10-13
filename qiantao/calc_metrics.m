function metrics = calc_metrics(I1s,I2s,I3s,I4s, period_px, M, row)
% 指标：THD(LS) / 正交 / 等幅 / 相移 / 覆盖率（固定0.2 + 分位数自适应）
[H,~] = size(I1s); if nargin<7||isempty(row), row = round(H/2); end

% 主频最小二乘拟合（THD）
x   = (0:size(I1s,2)-1).';  
w   = 2*pi/period_px;
Phi = [cos(w*x) sin(w*x) ones(numel(x),1)];
y   = I1s(row,:).';
beta = Phi \ y; 
yfit = Phi*beta;
THD  = norm(y - yfit) / max(norm(yfit), eps);

% 正交性（I1 vs I2 为例，和此前保持一致）
Z1 = I1s - mean(I1s,2); 
Z2 = I2s - mean(I2s,2);
orth = sum(Z1(:).*Z2(:)) / sqrt(sum(Z1(:).^2)*sum(Z2(:).^2));

% 等幅误差
A = [std(I1s(:)) std(I2s(:)) std(I3s(:)) std(I4s(:))];
amp_err = max(abs(A-mean(A)))/max(mean(A),eps);

% 相移（~90°）
phi = @(I) angle(sum( (I(row,:)-mean(I(row,:))).*exp(-1j*w*(0:numel(I(row,:))-1)) ));
wrapToPi_local = @(t) mod(t+pi, 2*pi) - pi;
d12 = rad2deg( wrapToPi_local( phi(I2s) - phi(I1s) ) );
d23 = rad2deg( wrapToPi_local( phi(I3s) - phi(I2s) ) );
d34 = rad2deg( wrapToPi_local( phi(I4s) - phi(I3s) ) );

% 覆盖率 —— 两套口径：固定阈值0.20 + 分位数自适应(30th)
cover_fixed  = mean(M(:) > 0.20);
th_adapt     = max(0.10, prctile(M(:), 30));   % 也可试 25~35
cover_adapt  = mean(M(:) > th_adapt);

metrics = struct( ...
    'THD',THD, ...
    'orthogonality',orth, ...
    'amp_rel_err',amp_err, ...
    'phase_deg',[d12,d23,d34], ...
    'coverage_Mgt0p2',cover_fixed, ...      % 和你以前字段名保持一致
    'coverage_adapt_p30',cover_adapt, ...   % 新增，自适应口径
    'th_adapt',th_adapt ...                 % 记录使用的自适应阈值
);
end
