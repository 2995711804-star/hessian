%% ���������λ
function [pha, B] = m_calc_warppred_phase6(files, N)
I1 = m_imread(files{1}); % ��ȡͼƬ
I1 = m_filter2d(I1);
I2 = m_imread(files{2}); % ��ȡͼƬ
I2 = m_filter2d(I2);
I3 = m_imread(files{3}); % ��ȡͼƬ
I3 = m_filter2d(I3);
I4 = m_imread(files{4}); % ��ȡͼƬ
I4 = m_filter2d(I4);
sin_sum=I4*sin(2*pi/4)+I1*sin(2*2*pi/4)+I2*sin(3*2*pi/4)+I3*sin(4*2*pi/4);
cos_sum=I4*cos(2*pi/4)+I1*cos(2*2*pi/4)+I2*cos(3*2*pi/4)+I3*cos(4*2*pi/4);


% ���ݼ�����λ�����ƶ�

pha = atan2(sin_sum, cos_sum);
B = sqrt(sin_sum .^ 2 + cos_sum .^ 2) * 2 / N;

%% ����ע�͵���Σ��Լ�����ʵ��һ��
% Ϊ�˽�������λתΪ���������ڵ�������
pha = - pha;
pha = pha + pi;
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