% %% 计算包裹相位
% function [pha, B] = m_calc_warppred_phase(files, files_grayCode,N)
% sin_sum = 0;
% cos_sum = 0;
% sin1=0;
% sin2=0;
% sin3=0;
% sin4=0;
% [~, n] = size(files_grayCode);
% Ib=m_imread(files_grayCode{n - 1});%提取全黑图像
% % Ib = m_filter2d(Ib);
% for k = 0: N/4 - 1
%     Ik = m_imread(files{k + 1}); % 读取图片
% %     Ik = m_filter2d(Ik);
%     if k==0
%         sin1 = sin1 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
%     elseif k==1
%         sin1 = sin1 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
%     elseif k==2
%         sin1 = sin1 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
%     elseif k==3
%         sin1 = sin1 + (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
%     end
%     sin1=m_filter2d(sin1);
% end
% for k = N/4: N/2 - 1
%     Ik = m_imread(files{k + 1}); % 读取图片
% %     Ik = m_filter2d(Ik);
% %     sin2 = sin2 + (Ik-Ib)*((k+1-6)/6);
%    if k==4
%         sin2 = sin2 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
%     elseif k==5
%         sin2 = sin2 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
%     elseif k==6
%         sin2 = sin2 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
%     elseif k==7
%         sin2 = sin2+ (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
%    end
%    sin2=m_filter2d(sin2);
% end
% 
% for k = N/2: 3*N/4 - 1
%     Ik = m_imread(files{k + 1}); % 读取图片
% %     Ik = m_filter2d(Ik);
% %     sin3 = sin3 + (Ik-Ib)*((k+1-12)/6);
%     if k==8
%         sin3 = sin3 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
%     elseif k==9
%         sin3 = sin3 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
%     elseif k==10
%         sin3 = sin3 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
%     elseif k==11
%         sin3 = sin3 + (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
%     end
%     sin3=m_filter2d(sin3);
% end
% 
% for k = 3*N/4:N-1
%     Ik = m_imread(files{k + 1}); % 读取图片
% %     Ik = m_filter2d(Ik);
% %     sin4 = sin4 + (Ik-Ib)*((k+1-18)/6);
%     if k==12
%         sin4 = sin4 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
%     elseif k==13
%         sin4 = sin4 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
%     elseif k==14
%         sin4 = sin4 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
%     elseif k==15
%         sin4 = sin4 + (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
%     end
%     sin4=m_filter2d(sin4);
% end
% 
% % 根据计算相位、调制度
% %计算截断相位
% sin_sum=sin3*sin(2*0*pi/4)+sin4*sin(2*pi/4)+sin1*sin(2*2*pi/4)+sin2*sin(3*2*pi/4);
% cos_sum=sin3*cos(2*pi*0/4)+sin4*cos(2*pi/4)+sin1*cos(2*2*pi/4)+sin2*cos(3*2*pi/4);
% pha = atan2(sin_sum, cos_sum);
% B = sqrt(sin_sum .^ 2 + cos_sum .^ 2) * 2 / 4;
% 
% %% 尝试注释掉这段，自己从零实现一遍
% % 为了将波折相位转为单个周期内单调递增
% pha = - pha;
% pha_low_mask = pha <= 0;
% pha = pha + pha_low_mask  .* 2. * pi;
% end
% 
% %% 读取图片
% function [img] = m_imread(file)
% img = imread(file);
% img = double(((img(:, :, 1)))); % 转换灰度图
% end
% 
% %% 高斯滤波
% function [img] = m_filter2d(img)
% w = 3.;
% sigma = 1.;
% kernel = fspecial("gaussian", [w, w], sigma);
% img = imfilter(img, kernel, "replicate");
% end
% 
% 
% 
% % %% 计算包裹相位
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
%% 计算包裹相位
function [pha, B] = m_calc_warppred_phase(files, N)

    % ---- 统一成文件名列表 ----
    if ischar(files) || (isstring(files) && isscalar(files))
        files = arrayfun(@(k) fullfile(char(files), sprintf('%d.bmp',k)), 1:N, 'uni', 0);
    else
        files = files(:).';
        assert(numel(files)==N, 'files 的长度应为 N');
    end

    % ---- 读取并轻度高斯去噪 ----
    Ik = cell(1,N);
    for k = 1:N
        Ik{k} = m_filter2d(m_imread(files{k}));
    end
    [H,W] = size(Ik{1});

    % ---- DFT 同步检波抽基波：c1 = (2/N) Σ I_k * e^{-j·2πk/N} ----
    ej = exp(-1j*2*pi*(0:N-1)/N);       % 1×N
    c1 = zeros(H,W);                    % complex
    for k = 1:N
        c1 = c1 + Ik{k} .* ej(k);
    end
    c1  = (2/N) * c1;

    % ---- 相位与调制度 ----

    pha_raw = mod(angle(c1), 2*pi);     % [0,2π)
    B       = abs(c1);                  % 基波幅值（调制度）

    % ---- 基于 B 的有效掩膜 + 复数域平滑（避免 0/2π 断层）----
    p95  = prctile(B(:),95);
    mask = B > 0.2*p95;                % 0.10~0.20 可调
    mask = imopen(mask,  strel('disk',2));
    mask = imclose(mask, strel('disk',3));
    mask = imfill(mask,'holes');
    mask = bwareaopen(mask, 400);

    pha   = wrap_smooth(pha_raw, mask, B, 1.5);  % sigma=1.0，可调 1.0~1.5
%pha=pha_raw;
end

%% 读取图片 -> 双精度灰度
function img = m_imread(file)
    I = imread(file);
    if ndims(I)==3, I = rgb2gray(I); else, I = I; end
    img = double(I);
end

%% 高斯滤波（轻度）
function img = m_filter2d(img)
    w = 3; sigma = 1.0;
    kernel = fspecial('gaussian', [w, w], sigma);
    img = imfilter(img, kernel, 'replicate');
end

%% 复数域加权高斯平滑：对 e^{jφ} 做平滑再取角度（不会在 0/2π 处开缝）
function phi_s = wrap_smooth(phi, mask, B, sigma)
    p95 = prctile(B(:),95);
    w   = (B - 0.12*p95) / (0.60*p95 - 0.12*p95);  % 线性映射到 0..1
    w   = min(max(w,0),1) .* double(mask);         % 乘掩膜
    z   = w .* exp(1j*phi);
    num = imgaussfilt(real(z),sigma) + 1j*imgaussfilt(imag(z),sigma);
    den = imgaussfilt(w, sigma) + eps;
    phi_s = mod(angle(num./den), 2*pi);
end
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
