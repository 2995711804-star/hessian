function [Q_adaptive, region_map] = m_calc_adaptive_quality_fusion(phi, difX, Q_hessian, edge_strength, feature_map)
% 文物特征自适应质量融合（创新点2, 升级稳健版）
% 输入同原函数；输出：
%   Q_adaptive ∈ [0,1]  自适应融合质量图
%   region_map ∈ {1,2,3} 1=平滑, 2=边缘, 3=纹理

    %#ok<*NASGU>
    [H,W] = size(phi);
    valid = isfinite(phi) & isfinite(difX) & isfinite(Q_hessian) ...
          & isfinite(edge_strength) & isfinite(feature_map);

    % ---------- 1) 稳健归一化 ----------
    M  = rnorm01(abs(difX), valid);       % 调制度
    Qh = rnorm01(Q_hessian,   valid);     % Hessian 质量
    E  = rnorm01(edge_strength, valid);
    F  = rnorm01(feature_map,   valid);

    % 轻平滑降低椒盐
    E = imgaussfilt(E, 1);
    F = imgaussfilt(F, 1);

    % ---------- 2) 区域分类（Otsu + 回退） ----------
    TE = otsu_on_valid(E, valid);
    TF = otsu_on_valid(F, valid);

    region_map = ones(H,W,'uint8');                 % 1=平滑
    region_map(E > TE) = 2;                         % 2=边缘
    region_map(E <= TE & F > TF) = 3;               % 3=纹理

    % 小斑块去噪（3x3最小面积=9像素）
    for lbl = 2:3
        mask = region_map==lbl;
        mask = bwareaopen(mask, 9);
        region_map(mask) = lbl;
        % 被清掉的像素回退到平滑类
        region_map(~mask & region_map==lbl) = 1;
    end

    % ---------- 3) 自适应权重 α ----------
    alpha = zeros(H,W);
    alpha(region_map==1) = 0.30;   % 平滑：偏调制度
    alpha(region_map==2) = 0.70;   % 边缘：偏Hessian
    alpha(region_map==3) = 0.50;   % 纹理：均衡

    % 局部微调：对 M 做中值去噪后再微调，tanh 抑制极端
    M_med = medfilt2(M, [3 3], 'symmetric');
    delta = 0.20 * tanh( (M_med - 0.5) / 0.25 );   % ∈[-0.2, 0.2]
    alpha = min(max(alpha .* (1 + delta), 0), 1);

    % ---------- 4) 融合 + 边缘/特征增强 ----------
    Q_adaptive = alpha .* Qh + (1 - alpha) .* M;

    % 抑制极端增强：幂压缩 + 上限
    gamma = 0.8;
    gain  = 1 + 0.25 * (E.^gamma + F.^gamma);      % ≤ 1.5
    gain  = min(gain, 1.5);
    Q_adaptive = Q_adaptive .* gain;

    % 仅在 valid 内归一化
    Q_adaptive = renorm_in_mask(Q_adaptive, valid);

    % 非法位置置零（或置 NaN 按需）
    Q_adaptive(~valid) = 0;
end

% ==================== 辅助函数 ====================

function Y = rnorm01(X, mask)
    x = X(mask);
    if isempty(x) || all(~isfinite(x))
        Y = zeros(size(X)); return;
    end
    lo = prctile(x,1); hi = prctile(x,99);
    if hi <= lo, Y = mat2gray(X);
    else
        Y = (X-lo)/(hi-lo);
        Y = min(max(Y,0),1);
    end
end

function T = otsu_on_valid(X, mask)
    x = X(mask);
    if numel(x) < 128 || std(x) < 1e-3
        T = 0.5; return;                       % 方差太小回退阈值
    end
    T = graythresh(x);                          % Otsu
    if ~isfinite(T), T = 0.5; end
end

function Y = renorm_in_mask(X, mask)
    Y = X;
    x = X(mask);
    if isempty(x)
        Y(:) = 0; return;
    end
    lo = prctile(x,1); hi = prctile(x,99);
    if hi > lo
        Y(mask) = (X(mask)-lo)/(hi-lo);
        Y(mask) = min(max(Y(mask),0),1);
    else
        Y(mask) = mat2gray(X(mask));
    end
end
