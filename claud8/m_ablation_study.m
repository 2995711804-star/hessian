function ablation_results = m_ablation_study(phaX, difX, Ac, Ap, prj_width)
% =========================================================================
% 消融实验：系统性验证每个创新点的独立贡献
% 输入：
%   - phaX: 原始相位图
%   - difX: 调制度图
%   - Ac, Ap: 相机和投影仪的投影矩阵
%   - prj_width: 投影仪宽度
% 输出：
%   - ablation_results: 包含所有配置结果的结构体
% =========================================================================

    fprintf('\n========================================\n');
    fprintf('    消融实验：验证创新点贡献\n');
    fprintf('========================================\n\n');
    
    [height, width] = size(phaX);
    
    % 定义实验配置
    configs = {
        % 配置名称, 使用多尺度, 使用自适应融合, 使用边缘精炼, 使用智能过滤
        'Baseline (传统方法)', false, false, false, false;
        '+ 多尺度Hessian', true, false, false, false;
        '+ 自适应融合', true, true, false, false;
        '+ 边缘保持精炼', true, true, true, false;
        'Full (完整方法)', true, true, true, true;
    };
    
    num_configs = size(configs, 1);
    ablation_results = cell(num_configs, 1);
    
    % 对每个配置进行实验
    for cfg_idx = 1:num_configs
        cfg_name = configs{cfg_idx, 1};
        use_multiscale = configs{cfg_idx, 2};
        use_adaptive = configs{cfg_idx, 3};
        use_refinement = configs{cfg_idx, 4};
        use_intelligent_filter = configs{cfg_idx, 5};
        
        fprintf('实验 %d/%d: %s\n', cfg_idx, num_configs, cfg_name);
        fprintf('  多尺度: %d, 自适应: %d, 精炼: %d, 智能过滤: %d\n', ...
                use_multiscale, use_adaptive, use_refinement, use_intelligent_filter);
        
        tic;
        
        % ============ 步骤1：质量图计算 ============
        if use_multiscale
            % 创新方法：多尺度Hessian
            scales = [1, 2, 4];
            [Q_hessian, edge_strength, feature_map] = m_calc_multiscale_hessian(phaX, scales);
        else
            % 传统方法：单尺度Hessian
            [gy, gx] = gradient(phaX);
            [gxx, ~] = gradient(gx);
            [~, gyy] = gradient(gy);
            traceH = abs(gxx + gyy);
            sigma = std(traceH(:));
            Q_hessian = exp(-traceH / (sigma + eps));
            
            % 简单边缘检测
            edge_strength = sqrt(gx.^2 + gy.^2);
            edge_strength = mat2gray(edge_strength);
            feature_map = edge_strength;  % 占位
        end
        
        % ============ 步骤2：质量融合 ============
        if use_adaptive
            % 创新方法：自适应融合
            [Q_final, region_map] = m_calc_adaptive_quality_fusion(phaX, difX, Q_hessian, edge_strength, feature_map);
        else
            % 传统方法：固定权重融合
            alpha = 0.5;
            difX_norm = mat2gray(abs(difX));
            Q_final = alpha * Q_hessian + (1 - alpha) * difX_norm;
            Q_final = mat2gray(Q_final);
            region_map = ones(size(phaX));  % 占位
        end
        
        % ============ 步骤3：相位精炼 ============
        if use_refinement
            % 创新方法：边缘保持精炼
            iterations = 15;
            [phaX_final, confidence_map] = m_edge_preserving_refinement(phaX, Q_final, edge_strength, iterations);
        else
            % 传统方法：简单中值滤波
            phaX_final = medfilt2(phaX, [3, 3]);
            confidence_map = Q_final;  % 占位
        end
        
        % ============ 步骤4：三维重建 ============
        x_p = phaX_final * prj_width;
        Xws = nan(height, width);
        Yws = nan(height, width);
        Zws = nan(height, width);
        
        % 固定阈值用于公平比较
        Q_threshold = 0.3;
        
        for y = 1:height
            for x = 1:width
                if phaX_final(y, x) > 0 && Q_final(y, x) > Q_threshold
                    uc = x - 1;
                    vc = y - 1;
                    up = (x_p(y, x) - 1);
                    
                    A = [Ac(1,1) - Ac(3,1) * uc, Ac(1,2) - Ac(3,2) * uc, Ac(1,3) - Ac(3,3) * uc;
                         Ac(2,1) - Ac(3,1) * vc, Ac(2,2) - Ac(3,2) * vc, Ac(2,3) - Ac(3,3) * vc;
                         Ap(1,1) - Ap(3,1) * up, Ap(1,2) - Ap(3,2) * up, Ap(1,3) - Ap(3,3) * up];
                    
                    b = [Ac(3,4) * uc - Ac(1,4);
                         Ac(3,4) * vc - Ac(2,4);
                         Ap(3,4) * up - Ap(1,4)];
                    
                    XYZ_w = A \ b;
                    Xws(y, x) = XYZ_w(1);
                    Yws(y, x) = XYZ_w(2);
                    Zws(y, x) = XYZ_w(3);
                end
            end
        end
        
        % ============ 步骤5：点云过滤 ============
        if use_intelligent_filter
            % 创新方法：智能过滤
            [ptCloud, outlier_map, filter_stats] = m_intelligent_pointcloud_filter(Xws, Yws, Zws, Q_final, edge_strength);
        else
            % 传统方法：简单过滤
            valid_mask = ~isnan(Xws) & ~isnan(Yws) & ~isnan(Zws);
            xyzPoints = [Xws(valid_mask), Yws(valid_mask), Zws(valid_mask)];
            ptCloud = pointCloud(xyzPoints);
            outlier_map = zeros(size(Xws));
            filter_stats.total_points = sum(valid_mask(:));
            filter_stats.filtered_points = ptCloud.Count;
            filter_stats.outlier_points = 0;
            filter_stats.retention_rate = 100;
        end
        
        compute_time = toc;
        
        % ============ 评估指标计算 ============
        % 1. 相位质量
        valid_mask = phaX > 0;
        phase_noise = std(phaX_final(valid_mask));
        phase_smoothness = mean(sqrt(gradient(phaX_final).^2 + gradient(phaX_final).^2), 'all', 'omitnan');
        
        % 2. 质量图统计
        Q_valid = Q_final(valid_mask);
        quality_mean = mean(Q_valid);
        quality_std = std(Q_valid);
        high_quality_ratio = sum(Q_valid > 0.7) / length(Q_valid) * 100;
        
        % 3. 边缘检测（与ground truth比较，这里用原始边缘作为参考）
        edge_gt = edge_strength > graythresh(edge_strength);
        edge_detected = Q_final < 0.5;  % 低质量区域可能是边缘
        TP = sum(edge_detected(:) & edge_gt(:));
        FP = sum(edge_detected(:) & ~edge_gt(:));
        FN = sum(~edge_detected(:) & edge_gt(:));
        edge_precision = TP / (TP + FP + eps);
        edge_recall = TP / (TP + FN + eps);
        edge_f1 = 2 * edge_precision * edge_recall / (edge_precision + edge_recall + eps);
        
        % 4. 点云质量
        point_count = ptCloud.Count;
        completeness = point_count / sum(valid_mask(:)) * 100;
        
        if point_count > 6
            try
                xyz = ptCloud.Location;
                [~, distances] = knnsearch(xyz, xyz, 'K', 7);
                point_smoothness = mean(std(distances(:, 2:end), 0, 2));
            catch
                point_smoothness = NaN;
            end
        else
            point_smoothness = NaN;
        end
        
        % 保存结果
        result = struct();
        result.config_name = cfg_name;
        result.compute_time = compute_time;
        
        % 相位指标
        result.phase_noise = phase_noise;
        result.phase_smoothness = phase_smoothness;
        
        % 质量图指标
        result.quality_mean = quality_mean;
        result.quality_std = quality_std;
        result.high_quality_ratio = high_quality_ratio;
        
        % 边缘检测指标
        result.edge_precision = edge_precision;
        result.edge_recall = edge_recall;
        result.edge_f1 = edge_f1;
        
        % 点云指标
        result.point_count = point_count;
        result.completeness = completeness;
        result.point_smoothness = point_smoothness;
        result.retention_rate = filter_stats.retention_rate;
        
        % 中间结果（用于可视化）
        result.phaX_final = phaX_final;
        result.Q_final = Q_final;
        result.edge_strength = edge_strength;
        result.ptCloud = ptCloud;
        
        ablation_results{cfg_idx} = result;
        
        fprintf('  计算时间: %.3f秒\n', compute_time);
        fprintf('  相位噪声: %.6f\n', phase_noise);
        fprintf('  平均质量: %.4f\n', quality_mean);
        fprintf('  边缘F1: %.4f\n', edge_f1);
        fprintf('  点云数量: %d (完整性: %.1f%%)\n\n', point_count, completeness);
    end
    
    % ============ 生成对比报告 ============
    fprintf('\n========================================\n');
    fprintf('    消融实验汇总\n');
    fprintf('========================================\n\n');
    
    % 创建对比表格
    fprintf('%-25s %10s %12s %12s %10s %12s %12s\n', ...
            '配置', '时间(s)', '相位噪声', '平均质量', '边缘F1', '点云数', '完整性(%)');
    fprintf('%s\n', repmat('-', 1, 110));
    
    baseline_noise = ablation_results{1}.phase_noise;
    baseline_quality = ablation_results{1}.quality_mean;
    baseline_f1 = ablation_results{1}.edge_f1;
    baseline_completeness = ablation_results{1}.completeness;
    
    for i = 1:num_configs
        r = ablation_results{i};
        
        % 计算相对改进
        noise_improve = (baseline_noise - r.phase_noise) / baseline_noise * 100;
        quality_improve = (r.quality_mean - baseline_quality) / baseline_quality * 100;
        f1_improve = (r.edge_f1 - baseline_f1) / baseline_f1 * 100;
        complete_improve = (r.completeness - baseline_completeness) / baseline_completeness * 100;
        
        fprintf('%-25s %10.3f %12.6f %12.4f %10.4f %12d %12.1f\n', ...
                r.config_name, r.compute_time, r.phase_noise, r.quality_mean, ...
                r.edge_f1, r.point_count, r.completeness);
        
        if i > 1
            fprintf('%-25s %10s %11.1f%% %11.1f%% %9.1f%% %12s %11.1f%%\n', ...
                    '(vs Baseline)', '', noise_improve, quality_improve, ...
                    f1_improve, '', complete_improve);
        end
    end
    
    % ============ 可视化对比 ============
    visualize_ablation_results(ablation_results);
end

function visualize_ablation_results(results)
    num_configs = length(results);
    
    % 图1：指标对比柱状图
    fig1 = figure('Name', '消融实验：定量指标对比', 'Position', [100, 100, 1400, 800]);
    
    metrics_names = {'相位噪声降低率(%)', '质量提升率(%)', '边缘F1提升率(%)', '完整性提升率(%)'};
    baseline = results{1};
    
    improvements = zeros(num_configs-1, 4);
    for i = 2:num_configs
        r = results{i};
        improvements(i-1, 1) = (baseline.phase_noise - r.phase_noise) / baseline.phase_noise * 100;
        improvements(i-1, 2) = (r.quality_mean - baseline.quality_mean) / baseline.quality_mean * 100;
        improvements(i-1, 3) = (r.edge_f1 - baseline.edge_f1) / baseline.edge_f1 * 100;
        improvements(i-1, 4) = (r.completeness - baseline.completeness) / baseline.completeness * 100;
    end
    
    config_labels = cell(num_configs-1, 1);
    for i = 2:num_configs
        config_labels{i-1} = results{i}.config_name;
    end
    
    for i = 1:4
        subplot(2, 2, i);
        bar(improvements(:, i), 'FaceColor', [0.2, 0.4, 0.8]);
        set(gca, 'XTickLabel', config_labels, 'XTickLabelRotation', 15);
        ylabel('改进率 (%)', 'FontWeight', 'bold');
        title(metrics_names{i}, 'FontWeight', 'bold');
        grid on;
        
        % 添加数值标签
        for j = 1:size(improvements, 1)
            text(j, improvements(j, i), sprintf('%.1f%%', improvements(j, i)), ...
                 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                 'FontSize', 9, 'FontWeight', 'bold');
        end
    end
    
    sgtitle('消融实验：相对基线方法的改进率', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 图2：质量图对比
    fig2 = figure('Name', '消融实验：质量图可视化对比', 'Position', [100, 100, 1600, 600]);
    for i = 1:num_configs
        subplot(2, num_configs, i);
        imagesc(results{i}.Q_final);
        axis image off;
        colormap(gca, hot);
        colorbar;
        title(results{i}.config_name, 'FontWeight', 'bold', 'FontSize', 10);
        
        subplot(2, num_configs, i + num_configs);
        imagesc(results{i}.phaX_final);
        axis image off;
        colormap(gca, jet);
        colorbar;
        title('精炼相位', 'FontWeight', 'bold', 'FontSize', 10);
    end
    sgtitle('消融实验：质量图与相位图对比', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 图3：点云对比
    fig3 = figure('Name', '消融实验：点云重建对比', 'Position', [100, 100, 1600, 800]);
    for i = 1:num_configs
        subplot(2, 3, i);
        if results{i}.ptCloud.Count > 0
            pcshow(results{i}.ptCloud, 'MarkerSize', 20);
            view(45, 30);
            axis tight;
        end
        title(sprintf('%s\n点数: %d', results{i}.config_name, results{i}.point_count), ...
              'FontWeight', 'bold', 'FontSize', 10);
        xlabel('X'); ylabel('Y'); zlabel('Z');
    end
    sgtitle('消融实验：点云重建效果对比', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 图4：雷达图（综合评估）
    fig4 = figure('Name', '消融实验：综合性能雷达图', 'Position', [100, 100, 800, 800]);
    
    % 归一化指标（越大越好）
    metrics_matrix = zeros(num_configs, 5);
    for i = 1:num_configs
        r = results{i};
        metrics_matrix(i, 1) = 1 / (r.phase_noise + eps);  % 噪声（倒数）
        metrics_matrix(i, 2) = r.quality_mean;              % 质量
        metrics_matrix(i, 3) = r.edge_f1;                   % 边缘F1
        metrics_matrix(i, 4) = r.completeness / 100;        % 完整性
        metrics_matrix(i, 5) = 1 / (r.compute_time + eps);  % 速度（倒数）
    end
    
    % 归一化到[0, 1]
    metrics_norm = (metrics_matrix - min(metrics_matrix)) ./ (max(metrics_matrix) - min(metrics_matrix) + eps);
    
    % 绘制雷达图
    theta = linspace(0, 2*pi, 6);
    metrics_labels = {'低噪声', '高质量', '边缘精度', '完整性', '计算速度'};
    
    colors = lines(num_configs);
    hold on;
    for i = 1:num_configs
        values = [metrics_norm(i, :), metrics_norm(i, 1)];  % 闭合
        plot(theta, values, '-o', 'LineWidth', 2, 'Color', colors(i, :), ...
             'DisplayName', results{i}.config_name, 'MarkerSize', 8);
    end
    
    % 设置极坐标
    ax = polaraxes;  % 使用 polaraxes 创建极坐标轴
    ax.ThetaTick = rad2deg(theta(1:end-1));  % 设置 ThetaTick
    ax.ThetaTickLabel = metrics_labels;
    ax.RLim = [0, 1];
    grid on;
    legend('Location', 'best', 'FontSize', 10);
    title('综合性能雷达图（归一化）', 'FontSize', 14, 'FontWeight', 'bold');
    
    % 保存所有图表
    saveas(fig1, 'ablation_metrics_comparison.png');
    saveas(fig2, 'ablation_quality_visualization.png');
    saveas(fig3, 'ablation_pointcloud_comparison.png');
    saveas(fig4, 'ablation_radar_chart.png');
    
    fprintf('可视化结果已保存。\n');
end