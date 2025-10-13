% 边缘保持的相位精炼（创新点3） 
% 使用质量引导的各向异性扩散，保护边缘同时平滑噪声
% 输入：
% - phi: 原始相位图 
% - Q_map: 质量图
% - edge_strength: 边缘强度图 
% - iterations: 迭代次数 % 输出：
% - phi_refined: 精炼后的相位图
% - confidence_map: 置信度图
function [phi_refined, confidence_map] = m_edge_preserving_refinement(phi, Q_map, edge_strength, iterations)
    if nargin < 4, iterations = 10; end
    phi = double(phi);
    Q  = mat2gray(Q_map);
    E  = mat2gray(edge_strength);

    % 参数
    lambda = 0.15;         % 步长 (<=0.25)
    k_edge = 0.20;         % 边缘阈值
    % 基于当前梯度的导通衰减
    kg_rel = 0.25;         % 相位梯度归一化阈值(相对分位数)

    phi_refined = phi;

    for it = 1:iterations
        % 当前梯度幅值（归一化到分位数尺度）
        [Gy, Gx] = gradient(phi_refined);
        Gmag = hypot(Gx, Gy);
        s = max(prctile(Gmag(:), 90), eps);     % 稳健尺度
        g_grad = exp(-(Gmag./max(s*kg_rel, eps)).^2);

        % 边缘停止函数（固定边缘先验）
        g_edge = exp(-(E./k_edge).^2);

        % 4-邻域（circshift更紧凑）
        phiN = circshift(phi_refined, [-1, 0]);
        phiS = circshift(phi_refined, [ 1, 0]);
        phiW = circshift(phi_refined, [ 0,-1]);
        phiE = circshift(phi_refined, [ 0, 1]);

        QN = circshift(Q, [-1,0]);  QS = circshift(Q, [1,0]);
        QW = circshift(Q, [0,-1]);  QE = circshift(Q, [0,1]);

        gN = circshift(g_edge .* g_grad, [-1,0]);
        gS = circshift(g_edge .* g_grad, [ 1,0]);
        gW = circshift(g_edge .* g_grad, [ 0,-1]);
        gE = circshift(g_edge .* g_grad, [ 0, 1]);

        % 对称化权重（调和平均更保守）
        wN = 2 ./ (1./max(Q,eps) + 1./max(QN,eps)) .* gN;
        wS = 2 ./ (1./max(Q,eps) + 1./max(QS,eps)) .* gS;
        wW = 2 ./ (1./max(Q,eps) + 1./max(QW,eps)) .* gW;
        wE = 2 ./ (1./max(Q,eps) + 1./max(QE,eps)) .* gE;

        % 更新
        update = wN.*(phiN - phi_refined) + wS.*(phiS - phi_refined) ...
               + wW.*(phiW - phi_refined) + wE.*(phiE - phi_refined);

        % 软门控混合（避免硬截断）
        blend = min(max((Q - 0.2)/(0.5 - 0.2 + eps), 0), 1);  % smoothstep[0.2,0.5]
        phi_pred = phi_refined + lambda * update;
        phi_refined = blend .* phi_pred + (1 - blend) .* phi;
    end

    % 置信度（稳健差异 + 质量）
    d = abs(phi_refined - phi);
    s = max(prctile(d(:), 90), eps);
    confidence_map = exp(-d./s) .* Q;
    confidence_map = mat2gray(confidence_map);
end
