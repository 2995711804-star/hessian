%% ���������λ
function [pha, B] = m_calc_warppred_phase(files, files_grayCode,N)
sin_sum = 0;
cos_sum = 0;
sin1=0;
sin2=0;
sin3=0;
sin4=0;
[~, n] = size(files_grayCode);
Ib=m_imread(files_grayCode{n - 1});%��ȡȫ��ͼ��
% Ib = m_filter2d(Ib);
for k = 0: N/4 - 1
    Ik = m_imread(files{k + 1}); % ��ȡͼƬ
%     Ik = m_filter2d(Ik);
    if k==0
        sin1 = sin1 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
    elseif k==1
        sin1 = sin1 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
    elseif k==2
        sin1 = sin1 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
    elseif k==3
        sin1 = sin1 + (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
    end
    sin1=m_filter2d(sin1);
end
for k = N/4: N/2 - 1
    Ik = m_imread(files{k + 1}); % ��ȡͼƬ
%     Ik = m_filter2d(Ik);
%     sin2 = sin2 + (Ik-Ib)*((k+1-6)/6);
   if k==4
        sin2 = sin2 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
    elseif k==5
        sin2 = sin2 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
    elseif k==6
        sin2 = sin2 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
    elseif k==7
        sin2 = sin2+ (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
   end
   sin2=m_filter2d(sin2);
end

for k = N/2: 3*N/4 - 1
    Ik = m_imread(files{k + 1}); % ��ȡͼƬ
%     Ik = m_filter2d(Ik);
%     sin3 = sin3 + (Ik-Ib)*((k+1-12)/6);
    if k==8
        sin3 = sin3 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
    elseif k==9
        sin3 = sin3 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
    elseif k==10
        sin3 = sin3 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
    elseif k==11
        sin3 = sin3 + (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
    end
    sin3=m_filter2d(sin3);
end

for k = 3*N/4:N-1
    Ik = m_imread(files{k + 1}); % ��ȡͼƬ
%     Ik = m_filter2d(Ik);
%     sin4 = sin4 + (Ik-Ib)*((k+1-18)/6);
    if k==12
        sin4 = sin4 + (Ik-Ib)*((1+sin((-4*pi)/16))/2);
    elseif k==13
        sin4 = sin4 + (Ik-Ib)*((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2);
    elseif k==14
        sin4 = sin4 + (Ik-Ib)*((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2);
    elseif k==15
        sin4 = sin4 + (Ik-Ib)*(1-(1+sin((4*pi)/16))/2);
    end
    sin4=m_filter2d(sin4);
end

% ���ݼ�����λ�����ƶ�
%����ض���λ
sin_sum=sin3*sin(2*0*pi/4)+sin4*sin(2*pi/4)+sin1*sin(2*2*pi/4)+sin2*sin(3*2*pi/4);
cos_sum=sin3*cos(2*pi*0/4)+sin4*cos(2*pi/4)+sin1*cos(2*2*pi/4)+sin2*cos(3*2*pi/4);
pha = atan2(sin_sum, cos_sum);
B = sqrt(sin_sum .^ 2 + cos_sum .^ 2) * 2 / 4;

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