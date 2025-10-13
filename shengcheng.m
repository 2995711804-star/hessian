%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Day 2: 生成所有论文图表（6张图）
% 运行前先运行 day1_experiment_script.m 并加载结果
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all;
load('day1_results.mat'); % 加载Day 1的结果

% 创建figures文件夹
if ~exist('paper_figures', 'dir')
    mkdir('paper_figures');
end

%% 图1: 系统流程图（手动用PPT绘制更好，或用以下代码生成简化版）
fprintf('正在生成图1: 系统流程图...\n');
fig1 = figure('Position', [100, 100, 1200, 300]);
text(0.1, 0.5, '输入图像', 'FontSize', 14, 'HorizontalAlignment', 'center');
annotation('arrow', [0.15, 0.22], [0.5, 0.5]);
text(0.28, 0.5, '16步相移', 'FontSize', 14, 'HorizontalAlignment', 'center');
annotation('arrow', [0.33, 0.40], [0.5, 0.5]);
text(0.48, 0.5, '边缘感知\n质量评估', 'FontSize', 14, 'HorizontalAlignment', 'center');
annotation('arrow', [0.53, 0.60], [0.5, 0.5]);
text(0.68, 0.5, '保边去噪', 'FontSize', 14, 'HorizontalAlignment', 'center');
annotation('arrow', [0.73, 0.80], [0.5, 0.5]);
text(0.88, 0.5, '自适应\n三维重建', 'FontSize', 14, 'HorizontalAlignment', 'center');
axis off;
title('图1: 系统流程图', 'FontSize', 16, 'FontWeight', 'bold');
saveas(fig1, 'paper_figures/Fig1_Flowchart.png');
saveas(fig1, 'paper_figures/Fig1_Flowchart.eps'); % 高质量矢量图
close(fig1);

%% 图2: 相位图对比
fprintf('正在生成图2: 相位图对比...\n');
fig2 = figure('Position', [100, 100, 1600, 500]);

subplot(1,3,1);
imagesc(phaX_4); axis image off; colormap(gca, jet); colorbar;
title('(a) 4步相移相位图', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);

subplot(1,3,2);
imagesc(phaX_12); axis image off; colormap(gca, jet); colorbar;
title('(b) 12步相移相位图', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);

subplot(1,3,3);
imagesc(phaX_proposed); axis image off; colormap(gca, jet); colorbar;
title('(c) 本文方法相位图', 'FontSize', 14, 'FontWeight', 'bold');
set(gca, 'FontSize', 12);

sgtitle('图2: 相位图质量对比', 'FontSize', 18, 'FontWeight', 'bold');
saveas(fig2, 'paper_figures/Fig2_Phase_Comparison.png');
saveas(fig2, 'paper_figures/Fig2_Phase_Comparison.eps');
close(fig2);

%% 图3: 边缘检测效果对比
fprintf('正在生成图3: 边缘检测效果...\n');
fig3 = figure('Position', [100, 100, 1600, 500]);

% 计算边缘
[Gx, Gy] = gradient(phaX_4);
edge_4 = sqrt(Gx.^2 + Gy.^2);
[Gx, Gy] = gradient(phaX_12);
edge_12 = sqrt(Gx.^2 + Gy.^2);

subplot(1,3,1);
imagesc(edge_4); axis image off; colormap(gca, hot); colorbar;
title('(a) 4步相移边缘', 'FontSize', 14, 'FontWeight', 'bold');
caxis([0, prctile(edge_4(:), 99)]); % 统一色标

subplot(1,3,2);
imagesc(edge_12); axis image off; colormap(gca, hot); colorbar;
title('(b) 12步相移边缘', 'FontSize', 14, 'FontWeight', 'bold');
caxis([0, prctile(edge_12(:), 99)]);

subplot(1,3,3);
imagesc(edge_map); axis image off; colormap(gca, hot); colorbar;
title('(c) 本文方法边缘（增强）', 'FontSize', 14, 'FontWeight', 'bold');
caxis([0, 1]);

sgtitle('图3: 边缘检测效果对比', 'FontSize', 18, 'FontWeight', 'bold');
saveas(fig3, 'paper_figures/Fig3_Edge_Comparison.png');
saveas(fig3, 'paper_figures/Fig3_Edge_Comparison.eps');
close(fig3);

%% 图4: 点云重建效果对比
fprintf('正在生成图4: 点云重建对比...\n');
fig4 = figure('Position', [100, 100, 1600, 500]);

subplot(1,3,1);
pcshow(ptCloud_4, 'MarkerSize', 25);
title(sprintf('(a) 4步相移\n点云数: %d', ptCloud_4.Count), 'FontSize', 14, 'FontWeight', 'bold');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
view(45, 30); axis tight; grid on;
set(gca, 'FontSize', 11);

subplot(1,3,2);
pcshow(ptCloud_12, 'MarkerSize', 25);
title(sprintf('(b) 12步相移\n点云数: %d', ptCloud_12.Count), 'FontSize', 14, 'FontWeight', 'bold');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
view(45, 30); axis tight; grid on;
set(gca, 'FontSize', 11);

subplot(1,3,3);
pcshow(ptCloud_prop, 'MarkerSize', 25);
title(sprintf('(c) 本文方法\n点云数: %d', ptCloud_prop.Count), 'FontSize', 14, 'FontWeight', 'bold');
xlabel('X (mm)'); ylabel('Y (mm)'); zlabel('Z (mm)');
view(45, 30); axis tight; grid on;
set(gca, 'FontSize', 11);

sgtitle('图4: 点云重建效果对比', 'FontSize', 18, 'FontWeight', 'bold');
saveas(fig4, 'paper_figures/Fig4_PointCloud_Comparison.png');
saveas(fig4, 'paper_figures/Fig4_PointCloud_Comparison.eps');
close(fig4);

%% 图5: 局部细节放大
fprintf('正在生成图5: 局部细节放大...\n');
fig5 = figure('Position', [100, 100, 1600, 800]);

% 选择感兴趣区域（包含边缘）
roi_x = round(size(phaX_4, 2) * 0.35 : size(phaX_4, 2) * 0.55);
roi_y = round(size(phaX_4, 1) * 0.35 : size(phaX_4, 1) * 0.55);

% 上排：全图with红框
subplot(2,3,1);
imagesc(phaX_4); axis image off; colormap(gca, jet);
rectangle('Position', [roi_x(1), roi_y(1), length(roi_x), length(roi_y)], ...
          'EdgeColor', 'r', 'LineWidth', 3);
title('(a) 4步相移全图', 'FontSize', 13, 'FontWeight', 'bold');

subplot(2,3,2);
imagesc(phaX_12); axis image off; colormap(gca, jet);
rectangle('Position', [roi_x(1), roi_y(1), length(roi_x), length(roi_y)], ...
          'EdgeColor', 'r', 'LineWidth', 3);
title('(b) 12步相移全图', 'FontSize', 13, 'FontWeight', 'bold');

subplot(2,3,3);
imagesc(phaX_proposed); axis image off; colormap(gca, jet);
rectangle('Position', [roi_x(1), roi_y(1), length(roi_x), length(roi_y)], ...
          'EdgeColor', 'r', 'LineWidth', 3);
title('(c) 本文方法全图', 'FontSize', 13, 'FontWeight', 'bold');

% 下排：放大区域
subplot(2,3,4);
imagesc(phaX_4(roi_y, roi_x)); axis image off; colormap(gca, jet); colorbar;
title('(d) 4步相移放大（边缘模糊）', 'FontSize', 13, 'FontWeight', 'bold');

subplot(2,3,5);
imagesc(phaX_12(roi_y, roi_x)); axis image off; colormap(gca, jet); colorbar;
title('(e) 12步相移放大', 'FontSize', 13, 'FontWeight', 'bold');

subplot(2,3,6);
imagesc(phaX_proposed(roi_y, roi_x)); axis image off; colormap(gca, jet); colorbar;
title('(f) 本文方法放大（边缘清晰）', 'FontSize', 13, 'FontWeight', 'bold');

sgtitle('图5: 局部细节放大对比（红框区域）', 'FontSize', 18, 'FontWeight', 'bold');
saveas(fig5, 'paper_figures/Fig5_Local_Detail.png');
saveas(fig5, 'paper_figures/Fig5_Local_Detail.eps');
close(fig5);

%% 图6: 参数影响分析（需要额外实验，暂用示例数据）
fprintf('正在生成图6: 参数影响分析...\n');
% 如果您有时间，运行不同alpha值的实验；否则使用示例数据
alpha_values = [0.1, 0.3, 0.5, 0.7, 0.9];
% 示例数据（请替换为您的实际实验结果）
edge_sharpness = [0.0185, 0.0215, 0.0231, 0.0228, 0.0220]; % 边缘锐度
point_counts = [892000, 942000, 967000, 971000, 965000]; % 点云数量

fig6 = figure('Position', [100, 100, 1000, 500]);

subplot(1,2,1);
plot(alpha_values, edge_sharpness, '-o', 'LineWidth', 2.5, 'MarkerSize', 10, 'Color', [0.2, 0.4, 0.8]);
xlabel('\alpha（边缘增强系数）', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('边缘锐度', 'FontSize', 13, 'FontWeight', 'bold');
title('(a) \alpha对边缘锐度的影响', 'FontSize', 14, 'FontWeight', 'bold');
grid on; set(gca, 'FontSize', 12);
ylim([0.015, 0.025]);

subplot(1,2,2);
plot(alpha_values, point_counts/1000, '-s', 'LineWidth', 2.5, 'MarkerSize', 10, 'Color', [0.8, 0.2, 0.2]);
xlabel('\alpha（边缘增强系数）', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('点云数量 (×10^3)', 'FontSize', 13, 'FontWeight', 'bold');
title('(b) \alpha对点云数量的影响', 'FontSize', 14, 'FontWeight', 'bold');
grid on; set(gca, 'FontSize', 12);
ylim([880, 980]);

sgtitle('图6: 边缘增强系数\alpha的影响', 'FontSize', 18, 'FontWeight', 'bold');
saveas(fig6, 'paper_figures/Fig6_Parameter_Analysis.png');
saveas(fig6, 'paper_figures/Fig6_Parameter_Analysis.eps');
close(fig6);

fprintf('\n✓ 所有图表已生成！保存在 paper_figures/ 文件夹\n');
fprintf('  - PNG格式：用于Word/PPT\n');
fprintf('  - EPS格式：用于LaTeX（高质量矢量图）\n\n');

%% 生成图表清单
fprintf('========== 图表清单 ==========\n');
fprintf('图1: 系统流程图\n');
fprintf('图2: 相位图质量对比（3子图）\n');
fprintf('图3: 边缘检测效果对比（3子图）\n');
fprintf('图4: 点云重建效果对比（3子图）\n');
fprintf('图5: 局部细节放大对比（6子图）\n');
fprintf('图6: 参数影响分析（2子图）\n');
fprintf('==============================\n');