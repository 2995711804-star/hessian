%% ���������λ
function [pha, B] = m_calc_warppred_phase(files, N)
sin_sum = 0;
cos_sum = 0;
for k = 0: N - 1
    Ik = m_imread(files{k + 1}); % ��ȡͼƬ
    Ik = m_filter2d(Ik);
    sin_sum = sin_sum + Ik * sin(2 * k * pi / N);
    cos_sum = cos_sum + Ik * cos(2 * k * pi / N);
end
% ���ݼ�����λ�����ƶ�

pha = atan2(sin_sum, cos_sum);
B = sqrt(sin_sum .^ 2 + cos_sum .^ 2) * 2 / N;

%% ����ע�͵���Σ��Լ�����ʵ��һ��
% Ϊ�˽�������λתΪ���������ڵ�������
pha = - pha;
pha_low_mask = pha <= 0;
pha = pha + pha_low_mask  .* 2. * pi;
end

%% ��ȡͼƬ
function [img] = m_imread(file)
img = imread(file);
img = double(((img(:, :, 1)))); % ת���Ҷ�ͼ
end

%% ��˹�˲�
function [img] = m_filter2d(img)
w = 3.;
sigma = 1.;
kernel = fspecial("gaussian", [w, w], sigma);
img = imfilter(img, kernel, "replicate");
end