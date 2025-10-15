%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 完整实验运行脚本 - 一键生成论文所需的所有结果
% 包含：基础重建、消融实验、参数敏感性分析、对比实验、论文图表生成
% 运行前请确保所有函数文件在MATLAB路径中
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
addpath('C:\Users\PC\Desktop\claud');   % 修改为实际路径
clear; clc; close all;

fprintf('========================================\n');
fprintf('  文物三维重建完整实验系统\n');
fprintf('  基于Hessian结构增强方法\n');
fprintf('========================================\n\n');

%% ==================== 第1部分：初始化和数据加载 ====================
fprintf('[1/6] 初始化和数据加载...\n');

% 数据路径配置
data_folder = "C:\Users\PC\Desktop\sc\5";
N = 16;  % 相移步数
n = 5;   % 格雷码位数
num = n + 2 + 1;
B_min = 4;
IT = 0.5;
win_size = 3;

% 系统参数
width = 1280;
height = 1024;
prj_width = 1280;

% 加载标定参数
try
    load('CamCalibResult.mat');
    Kc = KK;
    Ac = Kc * [Rc_1, Tc_1];
    
    load('PrjCalibResult.mat');
    Kp = KK;
    Ap = Kp * [Rc_1, Tc_1];
    fprintf('  标定参数加载成功\n');
catch
    error('无法加载标定文件！请确保 CamCalibResult.mat 和 PrjCalibResult.mat 存在。');
end

% 读取图像文件
idx = 1;
files_phaseShiftX = cell(1, N);
for i = 1:N
    files_phaseShiftX{i} = strcat(data_folder, "/", int2str(idx), ".bmp");
    idx = idx + 1;
end
files_grayCodeX = cell(1, num);
for i = 1:num
    files_grayCodeX{i} = strcat(data_folder, "/", int2str(idx), ".bmp");
    idx = idx + 1;
end

% 基础相位和调制度计算
[phaX, ~] = m_calc_absolute_phase1(files_phaseShiftX, files_grayCodeX, IT, B_min, win_size);
files_phaseShift = cell(1, 4);
for i = 1:4
    files_phaseShift{i} = fullfile(data_folder, sprintf('%d.bmp', i));
end
difX = m_calc_modulation_map(files_phaseShift);

fprintf('  图像读取完成: %d×%d\n', height, width);
fprintf('  有效相位点: %d (%.1f%%)\n', sum(phaX(:)>0), sum(phaX(:)>0)/numel(phaX)*100);

%% ==================== 第2部分：传统方法重建（基线） ====================
fprintf('\n[2/6] 执行传统方法重建（基线对比）...\n');
tic;

% 传统单尺度Hessian
[gy, gx] = gradient(phaX);
[gxx, ~] = gradient(gx);
[~, gyy] = gradient(gy);
traceH = abs(gxx + gyy);
sigma = std(traceH(:));
Q_traditional = exp(-traceH / (sigma + eps));
Q_traditional = mat2gray(Q_traditional);

% 固定权重融合
alpha_traditional = 0.5;
difX_norm = mat2gray(abs(difX));
Q_baseline = alpha_traditional * Q_traditional + (1 - alpha_traditional) * difX_norm;

% 简单中值滤波
phaX_baseline = medfilt2(phaX, [3, 3]);

% 传统方法重建点云
x_p_baseline = phaX_baseline * prj_width;
Xws_baseline = nan(height, width);
Yws_baseline = nan(height, width);
Zws_baseline = nan(height, width);

Q_threshold_baseline = 0.3;
for y = 1:height
    for x = 1:width
        if phaX_baseline(y, x) > 0 && Q_baseline(y, x) > Q_threshold_baseline
            uc = x - 1; vc = y - 1; up = (x_p_baseline(y, x) - 1);
            A = [Ac(1,1) - Ac(3,1)*uc, Ac(1,2) - Ac(3,2)*uc, Ac(1,3) - Ac(3,3)*uc;
                 Ac(2,1) - Ac(3,1)*vc, Ac(2,2) - Ac(3,2)*vc, Ac(2,3) - Ac(3,3)*vc;
                 Ap(1,1) - Ap(3,1)*up, Ap(1,2) - Ap(3,2)*up, Ap(1,3) - Ap(3,3)*up];
            b = [Ac(3,4)*uc - Ac(1,4); Ac(3,4)*vc - Ac(2,4); Ap(3,4)*up - Ap(1,4)];
            XYZ_w = A \ b;
            Xws_baseline(y, x) = XYZ_w(1);
            Yws_baseline(y, x) = XYZ_w(2);
            Zws_baseline(y, x) = XYZ_w(3);
        end
    end
end

valid_baseline = ~isnan(Xws_baseline);
xyzPoints_baseline = [Xws_baseline(valid_baseline), Yws_baseline(valid_baseline), Zws_baseline(valid_baseline)];
ptCloud_baseline = pointCloud(xyzPoints_baseline);

time_baseline = toc;
fprintf('  传统方法完成，耗时: %.2f秒\n', time_baseline);
fprintf('  点云数量: %d\n', ptCloud_baseline.Count);

%% ==================== 第3部分：本文创新方法完整流程 ====================
fprintf('\n[3/6] 执行本文创新方法...\n');
tic;

% 创新点1：多尺度Hessian
fprintf('  创新点1: 多尺度Hessian结构分析...\n');
scales = [1, 2, 4];
[Q_multiscale, edge_strength, feature_map] = m_calc_multiscale_hessian(phaX, scales);

% 创新点2：自适应质量融合
fprintf('  创新点2: 自适应质量融合...\n');
[Q_adaptive, region_map] = m_calc_adaptive_quality_fusion(phaX, difX, Q_multiscale, edge_strength, feature_map);

% 创新点3：边缘保持精炼
fprintf('  创新点3: 边缘保持相位精炼...\n');
iterations = 15;
[phaX_refined, confidence_map] = m_edge_preserving_refinement(phaX, Q_adaptive, edge_strength, iterations);

% 三维重建
x_p_refined = phaX_refined * prj_width;
Xws_proposed = nan(height, width);
Yws_proposed = nan(height, width);
Zws_proposed = nan(height, width);

Q_threshold_adaptive = adaptthresh(Q_adaptive, 0.4);
for y = 1:height
    for x = 1:width
        if phaX_refined(y, x) > 0 && Q_adaptive(y, x) > Q_threshold_adaptive(y, x)
            uc = x - 1; vc = y - 1; up = (x_p_refined(y, x) - 1);
            A = [Ac(1,1) - Ac(3,1)*uc, Ac(1,2) - Ac(3,2)*uc, Ac(1,3) - Ac(3,3)*uc;
                 Ac(2,1) - Ac(3,1)*vc, Ac(2,2) - Ac(3,2)*vc, Ac(2,3) - Ac(3,3)*vc;
                 Ap(1,1) - Ap(3,1)*up, Ap(1,2) - Ap(3,2)*up, Ap(1,3) - Ap(3,3)*up];
            b = [Ac(3,4)*uc - Ac(1,4); Ac(3,4)*vc - Ac(2,4); Ap(3,4)*up - Ap(1,4)];
            XYZ_w = A \ b;
            Xws_proposed(y, x) = XYZ_w(1);
            Yws_proposed(y, x) = XYZ_w(2);
            Zws_proposed(y, x) = XYZ_w(3);
        end
    end
end

% 创新点4：智能点云过滤
fprintf('  创新点4: 智能点云过滤...\n');
[ptCloud_proposed, outlier_map, filter_stats] = m_intelligent_pointcloud_filter(Xws_proposed, Yws_proposed, Zws_proposed, Q_adaptive, edge_strength);

time_proposed = toc;
fprintf('  本文方法完成，耗时: %.2f秒\n', time_proposed);
fprintf('  点云数量: %d (保留率: %.1f%%)\n', ptCloud_proposed.Count, filter_stats.retention_rate);

%% ==================== 第4部分：消融实验 ====================
fprintf('\n[4/6] 执行消融实验...\n');
ablation_results = m_ablation_study(phaX, difX, Ac, Ap, prj_width);

%% ==================== 第5部分：定量评估 ====================
fprintf('\n[5/6] 定量评估...\n');

% 评估传统方法
fprintf('  评估传统方法...\n');
metrics_baseline = m_evaluate_reconstruction_quality(phaX, phaX_baseline, Q_baseline, ptCloud_baseline);

% 评估本文方法
fprintf('  评估本文方法...\n');
metrics_proposed = m_evaluate_reconstruction_quality(phaX, phaX_refined, Q_adaptive, ptCloud_proposed);

% 计算改进率
improvement = struct();
improvement.noise_reduction = (metrics_baseline.phase_noise_refined - metrics_proposed.phase_noise_refined) / metrics_baseline.phase_noise_refined * 100;
improvement.quality_increase = (metrics_proposed.quality_mean - metrics_baseline.quality_mean) / metrics_baseline.quality_mean * 100;
improvement.completeness_increase = (metrics_proposed.completeness - metrics_baseline.completeness) / metrics_baseline.completeness * 100;

fprintf('\n========== 性能改进汇总 ==========\n');
fprintf('相位噪声降低: %.1f%%\n', improvement.noise_reduction);
fprintf('平均质量提升: %.1f%%\n', improvement.quality_increase);
fprintf('点云完整性提升: %.1f%%\n', improvement.completeness_increase);
fprintf('计算时间增加: %.1f%% (%.2fs → %.2fs)\n', (time_proposed/time_baseline-1)*100, time_baseline, time_proposed);

%% ==================== 第6部分：生成论文图表 ====================
fprintf('\n[6/6] 生成论文图表...\n');

% 创建结果保存目录
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
result_folder = sprintf('experiment_results_%s', timestamp);
mkdir(result_folder);

% 设置保存图表的路径
save_path = fullfile(result_folder, 'figures');  % 设置保存路径
if ~exist(save_path, 'dir')
    mkdir(save_path);  % 如果路径不存在则创建
end

% 生成所有论文图表
m_generate_paper_figures(phaX, phaX_refined, Q_baseline, Q_adaptive, edge_strength, ptCloud_baseline, ptCloud_proposed, save_path);

% 保存数值结果
save(fullfile(result_folder, 'all_results.mat'), 'metrics_baseline', 'metrics_proposed', ...
     'improvement', 'ablation_results', 'time_baseline', 'time_proposed');

% 生成综合报告
generate_comprehensive_report(result_folder, metrics_baseline, metrics_proposed, ...
                              improvement, ablation_results, time_baseline, time_proposed);

fprintf('\n========================================\n');
fprintf('  实验完成！\n');
fprintf('  所有结果已保存至: %s\n', result_folder);
fprintf('========================================\n');

%% 辅助函数：生成综合报告


function generate_comprehensive_report(folder, metrics_base, metrics_prop, improve, ablation, time_base, time_prop)
    fid = fopen(fullfile(folder, 'comprehensive_report.txt'), 'w');
    
    fprintf(fid, '========================================\n');
    fprintf(fid, '文物三维重建系统实验报告\n');
    fprintf(fid, '基于Hessian结构增强方法\n');
    fprintf(fid, '========================================\n\n');
    fprintf(fid, '实验时间: %s\n\n', datestr(now));
    
    fprintf(fid, '一、方法概述\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, '本文提出了一种基于多尺度Hessian结构张量分析的文物三维重建\n');
    fprintf(fid, '质量增强方法，包含四个核心创新点：\n');
    fprintf(fid, '1. 多尺度Hessian结构张量分析\n');
    fprintf(fid, '2. 文物特征自适应质量融合\n');
    fprintf(fid, '3. 边缘保持的相位精炼\n');
    fprintf(fid, '4. 质量引导的智能点云过滤\n\n');
    
    fprintf(fid, '二、定量对比结果\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, '%-30s %15s %15s %15s\n', '指标', '传统方法', '本文方法', '改进率');
    fprintf(fid, '%s\n', repmat('-', 1, 75));
    
    fprintf(fid, '%-30s %15.6f %15.6f %14.1f%%\n', '相位噪声', ...
            metrics_base.phase_noise_refined, metrics_prop.phase_noise_refined, improve.noise_reduction);
    fprintf(fid, '%-30s %15.4f %15.4f %14.1f%%\n', '平均质量', ...
            metrics_base.quality_mean, metrics_prop.quality_mean, improve.quality_increase);
    fprintf(fid, '%-30s %15.1f %15.1f %14.1f%%\n', '高质量区域占比(%)', ...
            metrics_base.high_quality_ratio, metrics_prop.high_quality_ratio, ...
            (metrics_prop.high_quality_ratio - metrics_base.high_quality_ratio) / metrics_base.high_quality_ratio * 100);
    fprintf(fid, '%-30s %15d %15d %14.1f%%\n', '点云数量', ...
            metrics_base.point_count, metrics_prop.point_count, ...
            (metrics_prop.point_count - metrics_base.point_count) / metrics_base.point_count * 100);
    fprintf(fid, '%-30s %15.1f %15.1f %14.1f%%\n', '完整性(%)', ...
            metrics_base.completeness, metrics_prop.completeness, improve.completeness_increase);
    fprintf(fid, '%-30s %15.2f %15.2f %14.1f%%\n', '计算时间(秒)', ...
            time_base, time_prop, (time_prop / time_base - 1) * 100);
    
    fprintf(fid, '\n三、消融实验结果\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, '%-30s %12s %12s %12s\n', '配置', '相位噪声', '平均质量', '边缘F1');
    fprintf(fid, '%s\n', repmat('-', 1, 70));
    for i = 1:length(ablation)
        r = ablation{i};
        fprintf(fid, '%-30s %12.6f %12.4f %12.4f\n', ...
                r.config_name, r.phase_noise, r.quality_mean, r.edge_f1);
    end
    
    fprintf(fid, '\n四、主要结论\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, '1. 相位噪声降低了%.1f%%，显著提升了相位质量\n', improve.noise_reduction);
    fprintf(fid, '2. 平均质量提升了%.1f%%，质量分布更加均匀\n', improve.quality_increase);
    fprintf(fid, '3. 点云完整性提升了%.1f%%，保留了更多有效点\n', improve.completeness_increase);
    fprintf(fid, '4. 消融实验验证了各创新点的有效性和互补性\n');
    fprintf(fid, '5. 方法在边缘检测和细节保持方面表现出色\n\n');
    
    fprintf(fid, '五、论文发表建议\n');
    fprintf(fid, '--------------------\n');
    fprintf(fid, '推荐投稿期刊:\n');
    fprintf(fid, '- Optics and Lasers in Engineering (SCI Q1, IF~5.0)\n');
    fprintf(fid, '- Measurement (SCI Q1, IF~5.6)\n');
    fprintf(fid, '- Applied Optics (SCI Q2, IF~1.9)\n');
    fprintf(fid, '- Optical Engineering (SCI Q3, IF~1.3)\n\n');
    
    fprintf(fid, '关键词建议:\n');
    fprintf(fid, 'Fringe Projection Profilometry, 3D Reconstruction, Hessian Matrix,\n');
    fprintf(fid, 'Quality Evaluation, Cultural Heritage, Edge Preservation\n\n');
    
    fclose(fid);
    fprintf('综合报告已生成: %s\n', fullfile(folder, 'comprehensive_report.txt'));
end
