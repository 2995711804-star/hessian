function phi_denoised = m_lightweight_denoise(phi, Q_map, edge_map, iterations)
% =========================================================================
% 轻量级保边去噪（简化版，避免过度平滑）
% 使用双边滤波思想，但更轻量
% 输入：
%   - phi: 原始相位图
%   - Q_map: 质量图
%   - edge_map: 边缘图
%   - iterations: 迭代次数（推荐3-5次）
% 输出：
%   - phi_denoised: 去噪后的相位图
% =========================================================================

    if nargin < 4
        iterations = 5;
    end
    
    phi = double(phi);
    [H, W] = size(phi);
    
    % 边缘保护掩码（边缘处不去噪）
    edge_protect = edge_map > graythresh(edge_map);
    
    % 质量掩码（只在高质量区域去噪）
    quality_mask = Q_map > 0.2;
    
    phi_denoised = phi;
    
    % 迭代去噪（非常保守）
    lambda = 0.2;  % 混合系数（很小，避免过度平滑）
    
    for iter = 1:iterations
        % 3x3 局部平均（权重由质量和边缘决定）
        phi_smooth = imfilter(phi_denoised, fspecial('average', 3), 'replicate');
        
        % 混合权重：
        % - 边缘区域：不混合（blend=0）
        % - 平滑区域：轻微混合（blend=lambda*Q）
        blend = lambda * Q_map .* (~edge_protect) .* quality_mask;
        
        % 更新（只在非边缘的高质量区域轻微平滑）
        phi_denoised = (1 - blend) .* phi_denoised + blend .* phi_smooth;
    end
    
    % 最终保护：确保边缘完全不变
    phi_denoised(edge_protect) = phi(edge_protect);
    
    fprintf('    去噪完成，边缘保护率: %.1f%%\n', sum(edge_protect(:))/numel(edge_protect)*100);
end