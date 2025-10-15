% 滤波
function [pha_new, dif] = m_filter2d(pha, win_size)
% 中值滤波（格雷码边缘处计算出现问题）
pha_new = medfilt2(pha, [win_size, win_size]);

% （剔除未编码区域）
dif = pha - pha_new;
end

