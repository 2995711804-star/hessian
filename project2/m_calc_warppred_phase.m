%% 计算包裹相位
function [pha, B] = m_calc_warppred_phase(files, N)
sin_sum = 0;
cos_sum = 0;
for k = 0: N - 1
    Ik = m_imread(files{k + 1}); % 读取图片
    Ik = m_filter2d(Ik);
    sin_sum = sin_sum + Ik * sin(2 * k * pi / N);
    cos_sum = cos_sum + Ik * cos(2 * k * pi / N);
end
% 根据计算相位、调制度

pha = atan2(sin_sum, cos_sum);
B = sqrt(sin_sum .^ 2 + cos_sum .^ 2) * 2 / N;

%% 尝试注释掉这段，自己从零实现一遍
% 为了将波折相位转为单个周期内单调递增
pha = - pha;
pha_low_mask = pha <= 0;
pha = pha + pha_low_mask  .* 2. * pi;
end

%% 读取图片
function [img] = m_imread(file)
img = imread(file);
img = double(((img(:, :, 1)))); % 转换灰度图
end

%% 高斯滤波
function [img] = m_filter2d(img)
w = 3.;
sigma = 1.;
kernel = fspecial("gaussian", [w, w], sigma);
img = imfilter(img, kernel, "replicate");
end