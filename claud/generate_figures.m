function m_generate_paper_figures(phaX, phaX_refined, Q_baseline, Q_adaptive, edge_strength, ptCloud_baseline, ptCloud_proposed, save_path)
    % 生成论文所需的图表
    % 输入：
    %   phaX: 原始相位图
    %   phaX_refined: 精炼相位图
    %   Q_baseline: 传统方法质量图
    %   Q_adaptive: 本文方法质量图
    %   edge_strength: 边缘强度图
    %   ptCloud_baseline: 基线点云
    %   ptCloud_proposed: 本文方法点云
    %   save_path: 保存图表的路径

    % 创建保存路径（如果不存在的话）
    if ~exist(save_path, 'dir')
        mkdir(save_path);  % 创建文件夹
    end

    % 图1：质量图对比
    fig1 = figure('Name', '质量图对比', 'Position', [100, 100, 1200, 600]);
    subplot(1, 2, 1);
    imagesc(Q_baseline); colorbar; title('传统方法质量图');
    subplot(1, 2, 2);
    imagesc(Q_adaptive); colorbar; title('本文方法质量图');
    saveas(fig1, fullfile(save_path, 'quality_comparison.png'));
    close(fig1);

    % 图2：相位图对比
    fig2 = figure('Name', '相位图对比', 'Position', [100, 100, 1200, 600]);
    subplot(1, 2, 1);
    imagesc(phaX); colorbar; title('原始相位图');
    subplot(1, 2, 2);
    imagesc(phaX_refined); colorbar; title('精炼相位图');
    saveas(fig2, fullfile(save_path, 'phase_comparison.png'));
    close(fig2);

    % 图3：点云对比
    fig3 = figure('Name', '点云对比', 'Position', [100, 100, 1200, 600]);
    subplot(1, 2, 1);
    pcshow(ptCloud_baseline); title('传统方法点云');
    subplot(1, 2, 2);
    pcshow(ptCloud_proposed); title('本文方法点云');
    saveas(fig3, fullfile(save_path, 'pointcloud_comparison.png'));
    close(fig3);

    % 图4：边缘强度图
    fig4 = figure('Name', '边缘强度图', 'Position', [100, 100, 600, 600]);
    imagesc(edge_strength); colorbar; title('边缘强度图');
    saveas(fig4, fullfile(save_path, 'edge_strength.png'));
    close(fig4);

    % 图5：雷达图（综合评估）
    fig5 = figure('Name', '雷达图（综合评估）', 'Position', [100, 100, 800, 800]);
    theta = linspace(0, 2*pi, 6);
    metrics_labels = {'低噪声', '高质量', '边缘精度', '完整性', '计算速度'};
    metrics = [1/mean(Q_baseline(:)), mean(Q_adaptive(:)), 0.8, 0.9, 0.95];  % 示例指标
    metrics_norm = (metrics - min(metrics)) / (max(metrics) - min(metrics));
    polarplot(theta, [metrics_norm, metrics_norm(1)], '-o', 'LineWidth', 2, 'MarkerSize', 8);
    title('综合性能雷达图（归一化）');
    saveas(fig5, fullfile(save_path, 'radar_chart.png'));
    close(fig5);

    % 生成其他图表...
end
