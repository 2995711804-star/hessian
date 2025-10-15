function [Q_edge_aware, edge_map] = m_edge_aware_quality(phi, difX)
% =========================================================================
% 边缘感知质量评估（简化版，确保效果提升）
% 核心思想：在边缘区域提升质量权重，保护文物细节
% 输入：
%   - phi: 相位图
%   - difX: 调制度图
% 输出：
%   - Q_edge_aware: 边缘感知质量图
%   - edge_map: 边缘强度图
% =========================================================================

    phi = double(phi);
    [H, W] = size(phi);
    
    % ========== 1. 基础质量图（调制度）==========
    Q_base = mat2gray(abs(difX));
    Q_base = imgaussfilt(Q_base, 0.8);  % 轻微平滑
    
    % ========== 2. 增强边缘检测 ==========
    % 使用Sobel算子（比Hessian更稳定）
    [Gx, Gy] = gradient(imgaussfilt(phi, 1));  % 先平滑再求梯度
    edge_mag = sqrt(Gx.^2 + Gy.^2);
    
    % 多尺度边缘融合
    edge_mag2 = sqrt(gradient(imgaussfilt(phi, 2)).^2 + gradient(imgaussfilt(phi, 2)).^2);
    edge_map = 0.7 * mat2gray(edge_mag) + 0.3 * mat2gray(edge_mag2);
    
    % ========== 3. 边缘增强的质量融合 ==========
    % 核心创新：在边缘区域提升质量权重
    edge_boost = 1 + 0.5 * edge_map;  % 边缘处质量提升最多50%
    
    Q_edge_aware = Q_base .* edge_boost;
    Q_edge_aware = mat2gray(Q_edge_aware);
    
    % ========== 4. 后处理：去除孤立噪点 ==========
    % 形态学开运算
    se = strel('disk', 1);
    Q_binary = Q_edge_aware > 0.2;
    Q_binary = imopen(Q_binary, se);
    Q_binary = bwareaopen(Q_binary, 20);  % 去除小于20像素的区域
    
    % 应用掩码
    Q_edge_aware = Q_edge_aware .* double(Q_binary);
    
    fprintf('    边缘增强质量图生成完成\n');
    fprintf('    边缘像素占比: %.2f%%\n', sum(edge_map(:) > 0.5) / numel(edge_map) * 100);
end