close all;
clc; clear;
tic;

%% 01 参数配置
W = 912;
H = 1140;

A = 130;
B = 90;

%
Num=16;

T=W/Num;



[I1] = make_phase1(A, B, T, W, H, 0);
[I2] = make_phase1(A, B, T, W, H, pi/2);
[I3] = make_phase1(A, B, T, W, H, pi);
[I4] = make_phase1(A, B, T, W, H, 3*pi/2);

un_wrap=atan2(I2-I4,I3-I1);

% figure(1);
% imshow(mat2gray(Is_img1));
% figure(2);
% imshow(mat2gray(Is_img2));
figure(3);
imshow(mat2gray(un_wrap));


imwrite(mat2gray(Is_img1),'1.bmp');