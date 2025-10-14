%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 3D recosntruction with the calibrated triangular stereo model.
% Related Reference:
% "Calibration of fringe projection profilometry: A comparative review"
% Shijie Feng, Chao Zuo, Liang Zhang, Tianyang Tao, Yan Hu, Wei Yin, Jiaming Qian, and Qian Chen
% last modified on 07/27/2020
% by Shijie Feng (Email: shijiefeng@njust.edu.cn)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Clear everything existing.
clc; clear;
close all;

data_folder = "date\project-40-3";
N = 32; %8幅二值*4步相移
n = 5;
num = n + 2 + 1;
B_min = 10;      % 低于这个调制度的我们就认为它的相位信息不可靠
IT = 0.5;        % 格雷码阈值
win_size = 1;    % 中值滤波窗口大小

%% step1: input parameters
width = 1280;    % camera width
height = 1024;    % camera height
prj_width = 1280; % projector width



%camera: Projection matrix Pc
load('CamCalibResult.mat');
Kc = KK;   % 相机内参
Ac = Kc * [Rc_1, Tc_1];

%projector: Projection matrix Pp
load('PrjCalibResult.mat');
Kp = KK;   % 投影仪内参
Ap = Kp * [Rc_1, Tc_1];       
       
%% step2: 读取测试图片并且计算三维重建
% % 条纹频率64，也是间距（一个周期由64个像素组成）用于计算绝对相位，频率1、8用于包裹相位展开
% f = 64;             % 条纹频率（单个周期条纹的像素个数），即P
% load('up_test_obj.mat');
% up_test_obj = up_test_obj / f;  % 将相位归一化到[0, 2pi]之间
% 
% figure; imshow(up_test_obj / (2 * pi)); colorbar; title("相位图, freq=" + num2str(f));
% figure; mesh(up_test_obj); colorbar; title("相位图, freq=" + num2str(f));
% 
% % 计算投影仪坐标
% x_p = up_test_obj / (2 * pi) * prj_width;

idx = 1;
files_phaseShiftX = cell(1, N);
for i = 1: N
        files_phaseShiftX{i} = strcat(data_folder, "/", int2str(idx), ".bmp");
        idx = idx + 1;
end
files_grayCodeX = cell(1, num);
for i = 1: num
    files_grayCodeX{i} = strcat(data_folder, "/", int2str(idx), ".bmp");
    idx = idx + 1;
end

[phaX, difX] = m_calc_absolute_phase8(files_phaseShiftX, files_grayCodeX, IT, B_min, win_size);
up_test_obj = phaX * 2 * pi;
x_p = phaX * prj_width;


% 3D重建
Xws = nan(height, width);
Yws = nan(height, width);
Zws = nan(height, width);

for y = 1:height
    for x = 1:width
        if ~(up_test_obj(y, x) == 0)
            uc = x - 1;
            vc = y - 1;
            up = (x_p(y, x) - 1);
             % Eq. (32) in the reference paper.
            A = [Ac(1,1) - Ac(3,1) * uc, Ac(1,2) - Ac(3,2) * uc, Ac(1,3) - Ac(3,3) * uc;
                 Ac(2,1) - Ac(3,1) * vc, Ac(2,2) - Ac(3,2) * vc, Ac(2,3) - Ac(3,3) * vc;
                 Ap(1,1) - Ap(3,1) * up, Ap(1,2) - Ap(3,2) * up, Ap(1,3) - Ap(3,3) * up]; 
            
            b = [Ac(3,4) * uc - Ac(1,4); 
                 Ac(3,4) * vc - Ac(2,4); 
                 Ap(3,4) * up - Ap(1,4)];
       
            XYZ_w = inv(A) * b;
            Xws(y, x) = XYZ_w(1); Yws(y, x) = XYZ_w(2); Zws(y, x) = XYZ_w(3);
        end
    end
end

% 点云显示
xyzPoints(:, 1) = Xws(:);
xyzPoints(:, 2) = Yws(:);
xyzPoints(:, 3) = Zws(:);
ptCloud = pointCloud(xyzPoints);
xlimits = [min(Xws(:)), max(Xws(:))];
ylimits = [min(Yws(:)), max(Yws(:))];
zlimits = ptCloud.ZLimits;
player = pcplayer(xlimits, ylimits, zlimits);
xlabel(player.Axes,'X (mm)');
ylabel(player.Axes,'Y (mm)');
zlabel(player.Axes,'Z (mm)');
view(player,ptCloud);

fid=fopen('xyz7.txt','w');
fprintf(fid,'%d %d %d\n',xyzPoints');
fclose(fid);