function [ptCloud_filtered, outlier_map, quality_stats] = m_intelligent_pointcloud_filter(Xws, Yws, Zws, Q_map, edge_strength)
% =========================================================================
% 质量引导的智能点云过滤（增强版，保边稳健）
% 结合“质量-空间-结构”三重一致性进行离群点检测（与旧版调用完全兼容）
% 输入：
%   - Xws, Yws, Zws: 原始点云坐标（h×w，含 NaN）
%   - Q_map: 质量图（任意动态范围，自动稳健归一化）
%   - edge_strength: 边缘强度图（可为[]，则自动从Z估计）
% 输出：
%   - ptCloud_filtered: 过滤后的点云（pointCloud）
%   - outlier_map: 离群点标记图（logical，h×w）
%   - quality_stats: 质量统计信息（struct）
% =========================================================================

    % ------------------------ 参数区（可按需修改） ------------------------
    cfg.window_size      = 5;        % 局部窗口（奇数）
    cfg.k_sigma_core     = 3.0;      % 非边缘区域Kσ阈值
    cfg.k_sigma_edge_mul = 1.6;      % 边缘放宽倍数（边缘阈值=Kσ*此倍数）
    cfg.Q_min_floor      = 0.10;     % 全局质量下限（归一化后）
    cfg.adapt_sens       = 0.5;      % adaptthresh灵敏度（越大阈值越低）
    cfg.morph.strel_r    = 1;        % 形态学结构元素半径（小=更保边）
    cfg.morph.min_area   = 9;        % 剔除小连通域阈值
    cfg.edge.auto_from_Z = true;     % 边缘图缺失时从Z自动估计
    cfg.edge.perc_thr    = 0.80;     % 边缘强度阈值（分位数）
    cfg.enable_normal    = false;    % 启用法向一致性（默认关）
    cfg.normal.cos_thr   = 0.94;     % 法向一致性阈值（~20°→0.94）
    epsv = 1e-12;

    % -------------------------- 输入与掩膜 ------------------------------
    [h, w] = size(Zws);
    valid_mask = ~isnan(Xws) & ~isnan(Yws) & ~isnan(Zws);

    % --------------------------- 质量图预处理 ----------------------------
    qn = normalize01_robust(Q_map);  % 稳健归一化到[0,1]

    % 自适应阈值（如无IPT，则回退到Otsu）
    low_quality_mask = false(h, w);
    try
        T = adaptthresh(qn, cfg.adapt_sens, 'ForegroundPolarity', 'bright');
        low_quality_mask = (qn < T) | (qn < cfg.Q_min_floor);
    catch
        t = graythresh(qn);  % Otsu
        low_quality_mask = (qn < max(t, 0.35)) | (qn < cfg.Q_min_floor);
    end

    % --------------------------- 边缘强度图 -----------------------------
    if (nargin < 5) || isempty(edge_strength) || all(edge_strength(:)==0 | isnan(edge_strength(:)))
        if cfg.edge.auto_from_Z
            edge_strength = infer_edge_from_Z(Zws);
        else
            edge_strength = zeros(h, w);
        end
    end
    e_norm = mat2gray(edge_strength);
    e_vals = e_norm(valid_mask);
    if isempty(e_vals), e_vals = e_norm(:); end
    e_thr = qtile(e_vals, cfg.edge.perc_thr);
    if ~isfinite(e_thr), e_thr = 0.7; end
    edge_region = e_norm >= e_thr;

    % --------------------- 局部均值/方差（忽略NaN） ----------------------
    ws = cfg.window_size;
    ker = ones(ws, ws, 'like', Zws);
    vm = valid_mask;

    cnt  = conv2(double(vm), ker, 'same');
    sumZ = conv2(replace_nan(Zws,0), ker, 'same');
    meanZ = sumZ ./ max(cnt, 1);

    sumZ2 = conv2(replace_nan(Zws.^2,0), ker, 'same');
    varZ  = max(sumZ2 ./ max(cnt,1) - meanZ.^2, 0);
    stdZ  = sqrt(varZ);

    % ------------------------- 深度一致性判定 ----------------------------
    K = cfg.k_sigma_core * ones(h, w);
    K(edge_region) = cfg.k_sigma_core * cfg.k_sigma_edge_mul;
    depth_outlier = abs(Zws - meanZ) > K .* max(stdZ, epsv);
    depth_outlier(~vm) = false;

    % ------------------------- 法向一致性（可选） ------------------------
    normal_outlier = false(h, w);
    if cfg.enable_normal
        [nx, ny, nz, n_valid] = estimate_normals_from_Z(Xws, Yws, Zws, vm);
        nxm = conv2(replace_nan(nx,0), ker, 'same') ./ max(conv2(double(n_valid), ker, 'same'), 1);
        nym = conv2(replace_nan(ny,0), ker, 'same') ./ max(conv2(double(n_valid), ker, 'same'), 1);
        nzm = conv2(replace_nan(nz,0), ker, 'same') ./ max(conv2(double(n_valid), ker, 'same'), 1);
        nm = sqrt(nxm.^2 + nym.^2 + nzm.^2) + epsv;
        nxm = nxm ./ nm; nym = nym ./ nm; nzm = nzm ./ nm;
        cosang = nx.*nxm + ny.*nym + nz.*nzm;
        normal_outlier = cosang < cfg.normal.cos_thr & n_valid;
    end

    % --------------------------- 综合判定 -------------------------------
    % 规则：
    %  1) 低质量 且 深度离群 → 剔除；
    %  2) 非边缘 且 深度离群 → 剔除；
    %  3) （可选）法向离群 且 低质量 → 剔除；
    outlier_map = ((low_quality_mask & depth_outlier) | (~edge_region & depth_outlier));
    if cfg.enable_normal
        outlier_map = outlier_map | (normal_outlier & low_quality_mask);
    end
    outlier_map = outlier_map & vm;

    % --------------------------- 形态学优化 ------------------------------
    se = strel('disk', cfg.morph.strel_r);
    outlier_map = imopen(outlier_map, se);  % 去毛刺，不连接边缘
    if cfg.morph.min_area > 0
        outlier_map = bwareaopen(outlier_map, cfg.morph.min_area);
    end

    % ----------------------------- 过滤 ---------------------------------
    filter_mask = vm & ~outlier_map;
    Xf = Xws; Yf = Yws; Zf = Zws;
    Xf(~filter_mask) = NaN; Yf(~filter_mask) = NaN; Zf(~filter_mask) = NaN;

    xyzPoints = [Xf(:), Yf(:), Zf(:)];
    keep = all(isfinite(xyzPoints), 2);
    xyzPoints = xyzPoints(keep, :);

    % 如需用Q着色，取消以下注释
    % qcol = uint8(255 * qn(:)); qcol = qcol(keep); C = repmat(qcol, 1, 3);
    % ptCloud_filtered = pointCloud(xyzPoints, 'Color', C);
    ptCloud_filtered = pointCloud(xyzPoints);

    % ----------------------------- 统计 ---------------------------------
    quality_stats.total_points     = nnz(vm);
    quality_stats.filtered_points  = nnz(filter_mask);
    quality_stats.outlier_points   = nnz(outlier_map);
    quality_stats.retention_rate   = pct(quality_stats.filtered_points, quality_stats.total_points);
    quality_stats.mean_quality     = mean(qn(filter_mask), 'omitnan');
    quality_stats.std_quality      = std(qn(filter_mask),  0, 'omitnan');
    quality_stats.edge_keep_rate   = pct(nnz(filter_mask & edge_region), nnz(vm & edge_region));
    quality_stats.params           = cfg;

    fprintf('[PointCloud Filter]\n');
    fprintf('  原始点数    : %d\n', quality_stats.total_points);
    fprintf('  保留点数    : %d\n', quality_stats.filtered_points);
    fprintf('  离群点数    : %d\n', quality_stats.outlier_points);
    fprintf('  保留率      : %.2f%%\n', quality_stats.retention_rate);
    fprintf('  平均质量    : %.4f ± %.4f\n', quality_stats.mean_quality, quality_stats.std_quality);
    fprintf('  边缘保留率  : %.2f%%\n', quality_stats.edge_keep_rate);
end

% ============================== 辅助函数 ===============================
function A = replace_nan(A, v)
    A(isnan(A)) = v;
end

function qn = normalize01_robust(Q)
    % 用2%/98%分位稳健归一化，避免极端值影响
    Qv = Q(isfinite(Q));
    if isempty(Qv)
        qn = zeros(size(Q));
        return;
    end
    lo = qtile(Qv, 0.02);
    hi = qtile(Qv, 0.98);
    if ~(isfinite(hi) && isfinite(lo)) || hi <= lo
        hi = max(Qv); lo = min(Qv);
    end
    qn = (Q - lo) ./ max(hi - lo, eps);
    qn = min(max(qn, 0), 1);
end

function e = infer_edge_from_Z(Z)
    % 从Z估计边缘强度（梯度幅值），对NaN鲁棒
    [Gx, Gy] = local_gradient_nan(Z);
    e = hypot(Gx, Gy);
    e = normalize01_robust(e);
end

function [Gx, Gy] = local_gradient_nan(Z)
    % 忽略NaN的简单梯度估计：前向差分+回填
    Zx = Z; Zy = Z;
    Zx(:,1:end-1) = Z(:,2:end) - Z(:,1:end-1);
    Zx(:,end) = Zx(:,end-1);
    Zy(1:end-1,:) = Z(2:end,:) - Z(1:end-1,:);
    Zy(end,:) = Zy(end-1,:);
    Zx(~isfinite(Zx)) = 0; Zy(~isfinite(Zy)) = 0;
    Gx = Zx; Gy = Zy;
end

function [nx, ny, nz, n_valid] = estimate_normals_from_Z(~, ~, Z, vm)
    % 基于局部坡度的近似法向：n = [-dz/dx, -dz/dy, 1] 归一化
    [dzdx, dzdy] = gradient_safe(Z);
    nx = -dzdx; ny = -dzdy; nz = ones(size(Z), 'like', Z);
    nrm = sqrt(nx.^2 + ny.^2 + nz.^2);
    n_valid = vm & isfinite(nrm) & nrm > 0;
    nx(~n_valid) = NaN; ny(~n_valid) = NaN; nz(~n_valid) = NaN;
    nx = nx ./ nrm; ny = ny ./ nrm; nz = nz ./ nrm;
end

function [gx, gy] = gradient_safe(A)
    % MATLAB gradient 的鲁棒版本（先用3×3邻域均值填NaN）
    A2 = A;
    nanmask = ~isfinite(A2);
    if any(nanmask(:))
        ker = ones(3);
        vm = double(~nanmask);
        cnt = conv2(vm, ker, 'same');
        sumA = conv2(replace_nan(A2,0), ker, 'same');
        A2(nanmask) = sumA(nanmask) ./ max(cnt(nanmask), 1);
    end
    [gx, gy] = gradient(A2);
    gx(~isfinite(gx)) = 0; gy(~isfinite(gy)) = 0;
end

function p = pct(a, b)
    if b <= 0, p = 0; else, p = 100 * double(a) / double(b); end
end

function q = qtile(v, p)
    % 分位数兼容：优先quantile，其次prctile，最后手写
    v = v(isfinite(v));
    if isempty(v), q = NaN; return; end
    try
        q = quantile(v, p);
    catch
        try
            q = prctile(v, p*100);
        catch
            v = sort(v(:));
            k = max(1, min(numel(v), round(p*numel(v))));
            q = v(k);
        end
    end
end
