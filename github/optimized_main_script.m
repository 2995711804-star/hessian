%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 文物边缘增强三维重建 - 渐进式优化方案
% 对比实验：4步相移 vs 12步相移 vs 本文方法（逐步优化）
% 核心目标：更清晰的边缘 + 更完整的点云
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc; close all;
addpath('C:\Users\PC\Desktop\claud');

fprintf('========================================\n');
fprintf('  文物边缘增强三维重建系统\n');
fprintf('  渐进式优化实验\n');
fprintf('========================================\n\n');

%% ==================== 参数配置 ====================
data_folder = "C:\Users\PC\Desktop\sc\5";
width = 1280;
height = 1024;
prj_width = 1280;
n = 5;
num = n + 2 + 1;
B_min = 4;
IT = 0.5;
win_size = 3;

% 加载标定
load('CamCalibResult.mat');
Kc = KK; Ac = Kc * [Rc_1, Tc_1];
load('PrjCalibResult.mat');
Kp = KK; Ap = Kp * [Rc_1, Tc_1];

%% ==================== 方法1: 4步相移（基线1）====================
fprintf('\n[方法1] 4步相移法（基线）...\n');
tic;

% 读取前4张图像
idx = 1;
files_4step = cell(1, 4);
for i = 1:4
    files_4step{i} = fullfile(data_folder, sprintf('%d.bmp', idx));
    idx = idx + 1;
end
idx = idx + 12; % 跳过剩余相移图

% 格雷码
files_grayCode = cell(1, num);
for i = 1:num
    files_grayCode{i} = strcat(data_folder, "/", int2str(idx), ".bmp");
    idx = idx + 1;
end

% 4步相移计算（简单包裹相位）
[phaX_4step, ~] = m_calc_absolute_phase1(files_4step, files_grayCode, IT, B_min, win_size);
difX_4step = m_calc_modulation_map(files_4step);

% 简单质量图（调制度）
Q_4step = mat2gray(abs(difX_4step));

% 三维重建
[ptCloud_4step, Xws_4step, Yws_4step, Zws_4step] = reconstruct_3d(phaX_4step, Q_4step, 0.25, Ac, Ap, prj_width);

time_4step = toc;
fprintf('  完成：%.2fs，点云数=%d\n', time_4step, ptCloud_4step.Count);

%% ==================== 方法2: 12步相移（基线2）====================
fprintf('\n[方法2] 12步相移法（改进基线）...\n');
tic;

% 读取前12张图像
idx = 1;
files_12step = cell(1, 12);
for i = 1:12
    files_12step{i} = fullfile(data_folder, sprintf('%d.bmp', idx));
    idx = idx + 1;
end
idx = idx + 4; % 跳过剩余相移图

% 12步相移计算
[phaX_12step, ~] = m_calc_absolute_phase1(files_12step, files_grayCode, IT, B_min, win_size);
difX_12step = m_calc_modulation_map(files_12step(1:4));

% 质量图（调制度 + 简单平滑）
Q_12step = imgaussfilt(mat2gray(abs(difX_12step)), 1);

% 三维重建
[ptCloud_12step, Xws_12step, Yws_12step, Zws_12step] = reconstruct_3d(phaX_12step, Q_12step, 0.25, Ac, Ap, prj_width);

time_12step = toc;
fprintf('  完成：%.2fs，点云数=%d\n', time_12step, ptCloud_12step.Count);

%% ==================== 方法3: 本文方法（16步+渐进优化）====================
fprintf('\n[方法3] 本文方法（16步相移 + 边缘增强）...\n');

% --- 步骤3.1: 高质量相位计算（16步）---
fprintf('  步骤3.1: 16步相移高质量相位计算...\n');
tic;
idx = 1;
files_16step = cell(1, 16);
for i = 1:16
    files_16step{i} = fullfile(data_folder, sprintf('%d.bmp', idx));
    idx = idx + 1;
end

[phaX_16step, ~] = m_calc_absolute_phase1(files_16step, files_grayCode, IT, B_min, win_size);
difX_16step = m_calc_modulation_map(files_16step(1:4));
time_step1 = toc;
fprintf('    耗时: %.2fs\n', time_step1);

% --- 步骤3.2: 边缘感知质量评估 ---
fprintf('  步骤3.2: 边缘感知质量评估...\n');
tic;
[Q_edge_aware, edge_map] = m_edge_aware_quality(phaX_16step, difX_16step);
time_step2 = toc;
fprintf('    耗时: %.2fs\n', time_step2);

% --- 步骤3.3: 保边去噪（轻量级）---
fprintf('  步骤3.3: 轻量级保边去噪...\n');
tic;
phaX_denoised = m_lightweight_denoise(phaX_16step, Q_edge_aware, edge_map, 5);
time_step3 = toc;
fprintf('    耗时: %.2fs\n', time_step3);

% --- 步骤3.4: 智能阈值点云重建 ---
fprintf('  步骤3.4: 自适应阈值三维重建...\n');
tic;
[ptCloud_proposed, Xws_prop, Yws_prop, Zws_prop] = reconstruct_3d_adaptive(phaX_denoised, Q_edge_aware, edge_map, Ac, Ap, prj_width);
time_step4 = toc;
fprintf('    耗时: %.2fs\n', time_step4);

time_proposed = time_step1 + time_step2 + time_step3 + time_step4;
fprintf('  总耗时: %.2fs，点云数=%d\n', time_proposed, ptCloud_proposed.Count);

%% ==================== 定量对比 ====================
fprintf('\n========== 定量对比结果 ==========\n');

results = struct();

% 方法1: 4步相移
results.method1 = evaluate_method(phaX_4step, Q_4step, ptCloud_4step, Xws_4step, Yws_4step, Zws_4step, '4步相移法');

% 方法2: 12步相移
results.method2 = evaluate_method(phaX_12step, Q_12step, ptCloud_12step, Xws_12step, Yws_12step, Zws_12step, '12步相移法');

% 方法3: 本文方法
results.method3 = evaluate_method(phaX_denoised, Q_edge_aware, ptCloud_proposed, Xws_prop, Yws_prop, Zws_prop, '本文方法');

% 打印对比表格
print_comparison_table(results);

%% ==================== 生成论文图表 ====================
fprintf('\n生成论文图表...\n');

% 创建保存目录
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
result_folder = sprintf('progressive_results_%s', timestamp);
mkdir(result_folder);

% 图1: 相位图对比
fig1 = figure('Position', [100, 100, 1600, 500]);
subplot(1,3,1); imagesc(phaX_4step); axis image off; colormap jet; colorbar;
title('(a) 4步相移相位图', 'FontSize', 12, 'FontWeight', 'bold');
subplot(1,3,2); imagesc(phaX_12step); axis image off; colormap jet; colorbar;
title('(b) 12步相移相位图', 'FontSize', 12, 'FontWeight', 'bold');
subplot(1,3,3); imagesc(phaX_denoised); axis image off; colormap jet; colorbar;
title('(c) 本文方法相位图', 'FontSize', 12, 'FontWeight', 'bold');
sgtitle('图1: 相位图质量对比', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig1, fullfile(result_folder, 'Fig1_Phase_Comparison.png'));
close(fig1);

% 图2: 边缘检测效果
fig2 = figure('Position', [100, 100, 1600, 500]);
subplot(1,3,1); 
[Gx, Gy] = gradient(phaX_4step);
edge_4step = sqrt(Gx.^2 + Gy.^2);
imagesc(edge_4step); axis image off; colormap hot; colorbar;
title('(a) 4步相移边缘', 'FontSize', 12, 'FontWeight', 'bold');

subplot(1,3,2);
[Gx, Gy] = gradient(phaX_12step);
edge_12step = sqrt(Gx.^2 + Gy.^2);
imagesc(edge_12step); axis image off; colormap hot; colorbar;
title('(b) 12步相移边缘', 'FontSize', 12, 'FontWeight', 'bold');

subplot(1,3,3);
imagesc(edge_map); axis image off; colormap hot; colorbar;
title('(c) 本文方法边缘（增强）', 'FontSize', 12, 'FontWeight', 'bold');
sgtitle('图2: 边缘检测效果对比', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig2, fullfile(result_folder, 'Fig2_Edge_Comparison.png'));
close(fig2);

% 图3: 点云对比
fig3 = figure('Position', [100, 100, 1600, 500]);
subplot(1,3,1);
pcshow(ptCloud_4step, 'MarkerSize', 20);
title(sprintf('(a) 4步相移\n点数: %d', ptCloud_4step.Count), 'FontSize', 12, 'FontWeight', 'bold');
view(45, 30); axis tight;

subplot(1,3,2);
pcshow(ptCloud_12step, 'MarkerSize', 20);
title(sprintf('(b) 12步相移\n点数: %d', ptCloud_12step.Count), 'FontSize', 12, 'FontWeight', 'bold');
view(45, 30); axis tight;

subplot(1,3,3);
pcshow(ptCloud_proposed, 'MarkerSize', 20);
title(sprintf('(c) 本文方法\n点数: %d', ptCloud_proposed.Count), 'FontSize', 12, 'FontWeight', 'bold');
view(45, 30); axis tight;

sgtitle('图3: 点云重建效果对比', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig3, fullfile(result_folder, 'Fig3_PointCloud_Comparison.png'));

% 保存所有结果
save(fullfile(result_folder, 'all_results.mat'), 'results', 'phaX_4step', 'phaX_12step', 'phaX_denoised', ...
     'Q_4step', 'Q_12step', 'Q_edge_aware', 'edge_map');

% 生成论文报告
generate_paper_report(result_folder, results, time_4step, time_12step, time_proposed);

fprintf('\n========================================\n');
fprintf('  实验完成！\n');
fprintf('  结果保存至: %s\n', result_folder);
fprintf('========================================\n');

%% ==================== 辅助函数 ====================

function [ptCloud, Xws, Yws, Zws] = reconstruct_3d(phaX, Q_map, threshold, Ac, Ap, prj_width)
    % 标准三维重建
    [height, width] = size(phaX);
    Xws = nan(height, width);
    Yws = nan(height, width);
    Zws = nan(height, width);
    
    x_p = phaX * prj_width;
    
    for y = 1:height
        for x = 1:width
            if phaX(y, x) > 0 && Q_map(y, x) > threshold
                uc = x - 1; vc = y - 1; up = (x_p(y, x) - 1);
                A = [Ac(1,1) - Ac(3,1)*uc, Ac(1,2) - Ac(3,2)*uc, Ac(1,3) - Ac(3,3)*uc;
                     Ac(2,1) - Ac(3,1)*vc, Ac(2,2) - Ac(3,2)*vc, Ac(2,3) - Ac(3,3)*vc;
                     Ap(1,1) - Ap(3,1)*up, Ap(1,2) - Ap(3,2)*up, Ap(1,3) - Ap(3,3)*up];
                b = [Ac(3,4)*uc - Ac(1,4); Ac(3,4)*vc - Ac(2,4); Ap(3,4)*up - Ap(1,4)];
                XYZ_w = A \ b;
                Xws(y, x) = XYZ_w(1);
                Yws(y, x) = XYZ_w(2);
                Zws(y, x) = XYZ_w(3);
            end
        end
    end
    
    valid = ~isnan(Xws);
    xyzPoints = [Xws(valid), Yws(valid), Zws(valid)];
    ptCloud = pointCloud(xyzPoints);
end

function [ptCloud, Xws, Yws, Zws] = reconstruct_3d_adaptive(phaX, Q_map, edge_map, Ac, Ap, prj_width)
    % 自适应阈值三维重建（边缘区域放宽阈值）
    [height, width] = size(phaX);
    Xws = nan(height, width);
    Yws = nan(height, width);
    Zws = nan(height, width);
    
    x_p = phaX * prj_width;
    
    % 自适应阈值
    base_threshold = 0.25;
    edge_threshold = 0.15;  % 边缘区域更低
    
    edge_binary = edge_map > graythresh(edge_map);
    
    for y = 1:height
        for x = 1:width
            if phaX(y, x) > 0
                % 根据是否在边缘区域选择阈值
                if edge_binary(y, x)
                    thr = edge_threshold;
                else
                    thr = base_threshold;
                end
                
                if Q_map(y, x) > thr
                    uc = x - 1; vc = y - 1; up = (x_p(y, x) - 1);
                    A = [Ac(1,1) - Ac(3,1)*uc, Ac(1,2) - Ac(3,2)*uc, Ac(1,3) - Ac(3,3)*uc;
                         Ac(2,1) - Ac(3,1)*vc, Ac(2,2) - Ac(3,2)*vc, Ac(2,3) - Ac(3,3)*vc;
                         Ap(1,1) - Ap(3,1)*up, Ap(1,2) - Ap(3,2)*up, Ap(1,3) - Ap(3,3)*up];
                    b = [Ac(3,4)*uc - Ac(1,4); Ac(3,4)*vc - Ac(2,4); Ap(3,4)*up - Ap(1,4)];
                    XYZ_w = A \ b;
                    Xws(y, x) = XYZ_w(1);
                    Yws(y, x) = XYZ_w(2);
                    Zws(y, x) = XYZ_w(3);
                end
            end
        end
    end
    
    valid = ~isnan(Xws);
    xyzPoints = [Xws(valid), Yws(valid), Zws(valid)];
    ptCloud = pointCloud(xyzPoints);
end

function metrics = evaluate_method(phaX, Q_map, ptCloud, Xws, Yws, Zws, method_name)
    % 评估单个方法
    metrics.name = method_name;
    
    % 相位噪声
    valid = phaX > 0 & ~isnan(phaX);
    metrics.phase_noise = std(phaX(valid));
    
    % 质量统计
    Q_valid = Q_map(valid);
    metrics.quality_mean = mean(Q_valid);
    metrics.quality_std = std(Q_valid);
    
    % 边缘锐度（梯度幅值）
    [Gx, Gy] = gradient(phaX);
    edge_strength = sqrt(Gx.^2 + Gy.^2);
    metrics.edge_sharpness = mean(edge_strength(valid));
    
    % 点云统计
    metrics.point_count = ptCloud.Count;
    metrics.completeness = ptCloud.Count / sum(valid(:)) * 100;
    
    % 点云平滑度
    if ptCloud.Count > 6
        try
            xyz = ptCloud.Location;
            [~, dist] = knnsearch(xyz, xyz, 'K', 7);
            metrics.smoothness = mean(std(dist(:, 2:end), 0, 2));
        catch
            metrics.smoothness = NaN;
        end
    else
        metrics.smoothness = NaN;
    end
end

function print_comparison_table(results)
    fprintf('\n%-20s %12s %12s %12s %12s %12s\n', ...
            '方法', '相位噪声', '平均质量', '边缘锐度', '点云数', '完整性(%)');
    fprintf('%s\n', repmat('-', 1, 100));
    
    methods = {results.method1, results.method2, results.method3};
    for i = 1:length(methods)
        m = methods{i};
        fprintf('%-20s %12.6f %12.4f %12.6f %12d %12.2f\n', ...
                m.name, m.phase_noise, m.quality_mean, m.edge_sharpness, ...
                m.point_count, m.completeness);
    end
    
    % 计算改进率
    fprintf('\n相对于4步相移的改进率:\n');
    base = results.method1;
    for i = 2:length(methods)
        m = methods{i};
        fprintf('%-20s: ', m.name);
        fprintf('噪声↓%.1f%%, ', (base.phase_noise - m.phase_noise)/base.phase_noise*100);
        fprintf('质量↑%.1f%%, ', (m.quality_mean - base.quality_mean)/base.quality_mean*100);
        fprintf('边缘↑%.1f%%, ', (m.edge_sharpness - base.edge_sharpness)/base.edge_sharpness*100);
        fprintf('点数↑%.1f%%\n', (m.point_count - base.point_count)/base.point_count*100);
    end
end

function generate_paper_report(folder, results, t1, t2, t3)
    fid = fopen(fullfile(folder, 'paper_report.txt'), 'w');
    
    fprintf(fid, '========================================\n');
    fprintf(fid, '文物边缘增强三维重建实验报告\n');
    fprintf(fid, '========================================\n\n');
    
    fprintf(fid, '一、实验方法对比\n');
    fprintf(fid, '%-20s %-20s %-15s\n', '方法', '描述', '计算时间');
    fprintf(fid, '%s\n', repmat('-', 1, 60));
    fprintf(fid, '%-20s %-20s %-15.2fs\n', '方法1', '4步相移（基线）', t1);
    fprintf(fid, '%-20s %-20s %-15.2fs\n', '方法2', '12步相移（改进）', t2);
    fprintf(fid, '%-20s %-20s %-15.2fs\n', '方法3', '本文方法（16步+边缘增强）', t3);
    
    fprintf(fid, '\n二、定量对比结果\n');
    fprintf(fid, '%-20s %12s %12s %12s %12s\n', ...
            '方法', '相位噪声', '平均质量', '边缘锐度', '点云数');
    fprintf(fid, '%s\n', repmat('-', 1, 80));
    
    methods = {results.method1, results.method2, results.method3};
    for i = 1:length(methods)
        m = methods{i};
        fprintf(fid, '%-20s %12.6f %12.4f %12.6f %12d\n', ...
                m.name, m.phase_noise, m.quality_mean, m.edge_sharpness, m.point_count);
    end
    
    fprintf(fid, '\n三、核心创新点\n');
    fprintf(fid, '1. 高质量相位计算：16步相移提供更准确的相位信息\n');
    fprintf(fid, '2. 边缘感知质量评估：区分边缘与平滑区域，保护文物细节\n');
    fprintf(fid, '3. 轻量级保边去噪：在降噪同时保持边缘锐度\n');
    fprintf(fid, '4. 自适应阈值重建：边缘区域使用更宽松阈值，提高完整性\n');
    
    fclose(fid);
end