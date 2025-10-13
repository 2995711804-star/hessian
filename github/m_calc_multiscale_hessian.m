function [Q_multiscale, edge_strength, feature_map] = m_calc_multiscale_hessian(phi, scales)
    if nargin < 2, scales = [1,2,4]; end
    phi = double(phi);
    [H,W] = size(phi);
    S = numel(scales);

    % 指数权重（细尺度更大）
    w = exp(-0.5*(0:S-1)); w = w/sum(w);

    Q_acc = zeros(H,W);
    E_acc = zeros(H,W);
    F_acc = zeros(H,W);

    for i = 1:S
        sigma = scales(i);

        % 1) 平滑
        phi_s = imgaussfilt(phi, sigma);

        % 2) 一/二阶导（注意次序与含义）
        [Gy, Gx]     = gradient(phi_s);
        [Gyy, Gyx]   = gradient(Gy);
        [Gxy, Gxx]   = gradient(Gx);

        % 3) Hessian（对称化）+ 尺度归一化 s^2
        Hxx = (sigma^2) * Gxx;
        Hyy = (sigma^2) * Gyy;
        Hxy = (sigma^2) * 0.5*(Gxy + Gyx);

        % 4) 特征值
        tr  = Hxx + Hyy;
        det = Hxx.*Hyy - Hxy.^2;
        disc = max(tr.^2 - 4*det, 0);
        lambda1 = 0.5*(tr + sqrt(disc));
        lambda2 = 0.5*(tr - sqrt(disc));

        % 5) 三个指标
        E = abs(lambda1);                          % 边缘强度
        F = sqrt(lambda1.^2 + lambda2.^2);         % 曲率强度

        % σ_F 采用稳健尺度（IQR）
        q10 = prctile(F(:),10); q90 = prctile(F(:),90);
        sigF = max(q90 - q10, eps);
        Q = exp(-F / sigF);

        % 6) 逐尺度稳健归一化再融合
        E = local_norm01(E); F = local_norm01(F); Q = local_norm01(Q);

        Q_acc = Q_acc + w(i)*Q;
        E_acc = E_acc + w(i)*E;
        F_acc = F_acc + w(i)*F;
    end

    Q_multiscale  = local_norm01(Q_acc);
    edge_strength = local_norm01(E_acc);
    feature_map   = local_norm01(F_acc);
end

function O = local_norm01(X)
    lo = prctile(X(:),1); hi = prctile(X(:),99);
    if hi <= lo, O = mat2gray(X);
    else, O = (X-lo)/(hi-lo); O = min(max(O,0),1); end
end
