function [Ks] = m_calc_gray_code(files, IT, n)
% 01 读取每一张图片进Is
[~, num] = size(files);
img = imread(files{1});
[h, w] = size(img);
Is = zeros(num, h, w);
for i = 1: num
    img = imread(files{i});
    Is(i, :, :) = double(img);
end

% 02 计算Is_Max、Is_Min，对每个点进行阈值判断
Is_max = max(Is);
Is_min = min(Is);
Is_std = (Is - Is_min) ./ (Is_max - Is_min);
gcs = Is_std > IT; 

% 03 对每个像素点，计算编码值V
Vs_row = zeros(1, 2 ^ n, 'uint8');
codes = m_gray_code(n);
for i = 1: 2 ^ n
    code = str2mat(codes(i)); %#ok<DSTRMT>
    V = 0;
    for j = 1: n
        V = V + str2num(code(j)) * 2^ (n - j); %#ok<ST2NM>
    end
    Vs_row(1, i) = V;
end

% 04 建立 V - > K 的映射表
V2K = containers.Map();
for K = 1: 2 ^ n
    V = Vs_row(1, K);
    V2K(int2str(V)) = K - 1;
end

Ks = zeros(h, w);
for v = 1: h
    %disp(strcat("第", int2str(v), "行"));
    for u = 1: w
        % 不需要最后黑、白两幅图片的编码
        gc = gcs(1: n, v, u);
        V = 0;
        for i = 1: n
            V = V + gc(i) * 2 ^ (n - i);
        end
        % 主要的性能瓶颈
        Ks(v, u) = V2K(int2str(V));
    end
end
end

