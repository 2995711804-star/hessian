function metrics = m_evaluate_reconstruction_quality(phaX_original, phaX_refined, Q_map, ptCloud, edge_ground_truth)
% =========================================================================
% 三维重建质量定量评估
% 输入：
%   - phaX_original: 原始相位
%   - phaX_refined: 精炼相位
%   - Q_map: 质量图
%   - ptCloud: 点云
%   - edge_ground_truth: 边缘真值（可选，用于边缘检测评估）
% 输出：
%   - metrics: 包含所有评估指标的结构体
% =========================================================================

    metrics = struct();
    
    %% 1. 相位质量指标
    % 相位噪声水平（标准差）
    valid_mask = phaX_original > 0 & ~isnan(phaX_original);
    metrics.phase_noise_original = std(phaX_original(valid_mask));
    metrics.phase_noise_refined = std(phaX_refined(valid_mask));
    metrics.noise_reduction_ratio = (metrics.phase_noise_original - metrics.phase_noise_refined) / ...
                                    metrics.phase_noise_original * 100;
    
    % 相位平滑度（梯度幅值的平均）
    [Gx_orig, Gy_orig] = gradient(phaX_original);
    [Gx_ref, Gy_ref] = gradient(phaX_refined);
    grad_mag_orig = sqrt(Gx_orig.^2 + Gy_orig.^2);
    grad_mag_ref = sqrt(Gx_ref.^2 + Gy_ref.^2);
    metrics.phase_smoothness_original = mean(grad_mag_orig(valid_mask));
    metrics.phase_smoothness_refined = mean(grad_mag_ref(valid_mask));
    
    % 相位连续性（拉普拉斯平滑度）
    laplacian_orig = del2(phaX_original);
    laplacian_ref = del2(phaX_refined);
    metrics.phase_continuity_original = mean(abs(laplacian_orig(valid_mask)));
    metrics.phase_continuity_refined = mean(abs(laplacian_ref(valid_mask)));
    
    %% 2. 质量图指标
    Q_valid = Q_map(valid_mask);
    metrics.quality_mean = mean(Q_valid);
    metrics.quality_std = std(Q_valid);
    metrics.quality_median = median(Q_valid);
    metrics.quality_max = max(Q_valid);
    metrics.quality_min = min(Q_valid);
    
    % 质量分布（高中低质量区域占比）
    metrics.high_quality_ratio = sum(Q_valid > 0.7) / length(Q_valid) * 100;
    metrics.medium_quality_ratio = sum(Q_valid >= 0.4 & Q_valid <= 0.7) / length(Q_valid) * 100;
    metrics.low_quality_ratio = sum(Q_valid < 0.4) / length(Q_valid) * 100;
    
    % 质量均匀性（变异系数）
    metrics.quality_uniformity = metrics.quality_std / metrics.quality_mean;
    
    %% 3. 点云质量指标
    if ~isempty(ptCloud) && ptCloud.Count > 0
        xyz = ptCloud.Location;
        
        % 点云密度
        metrics.point_count = ptCloud.Count;
        metrics.point_density = ptCloud.Count / (numel(phaX_original) - sum(isnan(phaX_original(:))));
        
        % 点云完整性（有效点占比）
        metrics.completeness = ptCloud.Count / sum(valid_mask(:)) * 100;
        
        % 点云平滑度（局部邻域标准差）
        try
            [~, distances] = knnsearch(xyz, xyz, 'K', 7); % 6个最近邻
            local_std = std(distances(:, 2:end), 0, 2); % 排除自身
            metrics.point_cloud_smoothness = mean(local_std);
            metrics.point_cloud_smoothness_std = std(local_std);
        catch
            metrics.point_cloud_smoothness = NaN;
            metrics.point_cloud_smoothness_std = NaN;
        end
        
        % 点云范围
        metrics.x_range = range(xyz(:, 1));
        metrics.y_range = range(xyz(:, 2));
        metrics.z_range = range(xyz(:, 3));
        
        % 深度分辨率
        metrics.depth_resolution = std(xyz(:, 3));
    else
        metrics.point_count = 0;
        metrics.point_density = 0;
        metrics.completeness = 0;
        metrics.point_cloud_smoothness = NaN;
    end
    
    %% 4. 边缘检测指标（如果提供真值）
    if nargin >= 5 && ~isempty(edge_ground_truth)
        % 从质量图导出边缘
        [Gx_Q, Gy_Q] = gradient(Q_map);
        edge_detected = sqrt(Gx_Q.^2 + Gy_Q.^2);
        edge_detected = edge_detected > graythresh(edge_detected);
        
        edge_gt = edge_ground_truth > 0;
        
        % 真阳性、假阳性、假阴性
        TP = sum(edge_detected(:) & edge_gt(:));
        FP = sum(edge_detected(:) & ~edge_gt(:));
        FN = sum(~edge_detected(:) & edge_gt(:));
        TN = sum(~edge_detected(:) & ~edge_gt(:));
        
        % 精确率、召回率、F1分数
        metrics.edge_precision = TP / (TP + FP + eps);
        metrics.edge_recall = TP / (TP + FN + eps);
        metrics.edge_f1_score = 2 * metrics.edge_precision * metrics.edge_recall / ...
                               (metrics.edge_precision + metrics.edge_recall + eps);
        metrics.edge_accuracy = (TP + TN) / (TP + FP + FN + TN);
    end
    
    %% 5. 计算效率指标（需要在调用时传入时间）
    % 这些将在主程序中添加
    
    %% 显示评估报告
    fprintf('\n========== 重建质量评估报告 ==========\n\n');
    fprintf('【相位质量】\n');
    fprintf('  噪声水平（原始）: %.6f\n', metrics.phase_noise_original);
    fprintf('  噪声水平（精炼）: %.6f\n', metrics.phase_noise_refined);
    fprintf('  噪声降低率: %.2f%%\n', metrics.noise_reduction_ratio);
    fprintf('  平滑度改善: %.2f%%\n', (1 - metrics.phase_smoothness_refined/metrics.phase_smoothness_original)*100);
    fprintf('  连续性改善: %.2f%%\n', (1 - metrics.phase_continuity_refined/metrics.phase_continuity_original)*100);
    
    fprintf('\n【质量图统计】\n');
    fprintf('  平均质量: %.4f ± %.4f\n', metrics.quality_mean, metrics.quality_std);
    fprintf('  中位数质量: %.4f\n', metrics.quality_median);
    fprintf('  质量范围: [%.4f, %.4f]\n', metrics.quality_min, metrics.quality_max);
    fprintf('  高质量区域: %.2f%%\n', metrics.high_quality_ratio);
    fprintf('  中质量区域: %.2f%%\n', metrics.medium_quality_ratio);
    fprintf('  低质量区域: %.2f%%\n', metrics.low_quality_ratio);
    fprintf('  质量均匀性: %.4f\n', metrics.quality_uniformity);
    
    fprintf('\n【点云质量】\n');
    fprintf('  点云数量: %d\n', metrics.point_count);
    fprintf('  点云密度: %.4f\n', metrics.point_density);
    fprintf('  完整性: %.2f%%\n', metrics.completeness);
    if ~isnan(metrics.point_cloud_smoothness)
        fprintf('  局部平滑度: %.4f ± %.4f\n', metrics.point_cloud_smoothness, metrics.point_cloud_smoothness_std);
    end
    fprintf('  空间范围: X=%.2f, Y=%.2f, Z=%.2f mm\n', metrics.x_range, metrics.y_range, metrics.z_range);
    
    if isfield(metrics, 'edge_f1_score')
        fprintf('\n【边缘检测】\n');
        fprintf('  精确率: %.4f\n', metrics.edge_precision);
        fprintf('  召回率: %.4f\n', metrics.edge_recall);
        fprintf('  F1分数: %.4f\n', metrics.edge_f1_score);
        fprintf('  准确率: %.4f\n', metrics.edge_accuracy);
    end
    
    fprintf('\n======================================\n\n');
end