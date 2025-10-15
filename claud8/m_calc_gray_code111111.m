% function [Vv1,Vv2] = m_calc_gray_code111111(files, IT, n)
% 
% %索引法-映射数组
% C1=[0 1 3 2 7 6 4 5 15 14 12 13 8 9 11 10 31 30 28 29 24 25 27 26 16 17 19 18 23 22 20 21];
% C2=[0 1 3 2 7 6 4 5 15 14 12 13 8 9 11 10 31 30 28 29 24 25 27 26 16 17 19 18 23 22 20 21 63 62 60 61 56 57 59 58 48 49 51 50 55 54 52 53 32 33 35 34 39 38 36 37 47 46 44 45 40 41 43 42];
% 
% % 01 读取每一张图片进Is
% [~, num] = size(files);
% G1=num-2;
% G=G1-1;
% img = imread(files{1});
% [h, w] = size(img);
% Is = zeros(num, h, w);
% for i = 1: num
%     img = imread(files{i});
%     Is(i, :, :) = double(img);
% end
% 
% % 02 格雷码二值化-计算Is_Max、Is_Min，对每个点进行阈值判断
% Is_max = max(Is);
% Is_min = min(Is);
% Is_std = (Is - Is_min) ./ (Is_max - Is_min);
% gcs = Is_std > IT; 
% 
% % 03计算码字-不需要最后黑、白两幅图片的编码
% for v = 1: h
%     %disp(strcat("第", int2str(v), "行"));
%     for u = 1: w
%     gc1 = gcs(1: n,v,u);
%     V1 = 0;
%     V2 = 0;
%     V1 = V1 + gc1(1) * 2 ^ (G - 1)+gc1(2) * 2 ^ (G - 2)+gc1(3) * 2 ^ (G - 3)+gc1(4) * 2 ^ (G - 4)+gc1(5) * 2 ^ (G - 5);  
%     V2 = V2 + gc1(1) * 2 ^ (G1 - 1)+gc1(2) * 2 ^ (G1 - 2)+gc1(3) * 2 ^ (G1 - 3)+gc1(4) * 2 ^ (G1 - 4)+gc1(5) * 2 ^ (G1 - 5)+gc1(6) * 2 ^ (G1 - 6); 
%     % 04数组映射
%     Vv1(v,u) = C1(V1+1);
% %     Vv2(v,u) = C2(V2+1);
%     Vv2(v,u)=floor((C2(V2+1)+1)/2);
%     end
% end
% 
% 
% 


function [k1,k2] = m_calc_gray_code111111(files)

%% 1.构建映射数组
% C3=[0 1 3 2 7 6 4 5];
C4=[0 1 3 2 7 6 4 5 15 14 12 13 8 9 11 10];
C5=[0 1 3 2 7 6 4 5 15 14 12 13 8 9 11 10 31 30 28 29 24 25 27 26 16 17 19 18 23 22 20 21];
C6=[0 1 3 2 7 6 4 5 15 14 12 13 8 9 11 10 31 30 28 29 24 25 27 26 16 17 19 18 23 22 20 21 63 62 60 61 56 57 59 58 48 49 51 50 55 54 52 53 32 33 35 34 39 38 36 37 47 46 44 45 40 41 43 42]; 
C7(1:64)=C6;
C7(65:96)=C6(33:64)+64;
C7(97:128)=C6(1:32)+64;
% C8(1:128)=C7;
% C8(129:192)=C7(65:128)+128;
% C8(193:256)=C7(1:64)+128;
% C9(1:256)=C8;
% C9(256+1:384)=C8(129:256)+256;
% C9(385:512)=C8(1:128)+256;

%% 2.读取格雷码
[~, num] = size(files);
img = imread(files{1});
[h, w] = size(img);

%% 3.计算格雷码二值化的阈值
QB = imread(files{num-1});
QW = imread(files{num});
A=(QB+QW)./2;

%% 4.格雷码二进制解码
sum=zeros(h,w);
sum1=zeros(h,w);
n=num-2;
for i = 1: n-1
    img = imread(files{i});%读取格雷码
    img = double(img);%将图片数据转为double类型
    img = erzhihua(A,img);%格雷码二值化函数
    %进制解码
    sum=img*2.^(n-1-i)+sum;
    sum1=img*2.^(n-i)+sum1;
end
%互补格雷码解码
img1 = imread(files{n});
img1 = double(img1);
img1 = erzhihua(A,img1);
sum1=sum1+img1*2.^(num-num);

%% 5计算阶梯级次和互补阶梯级次
k1=C6(sum+1);
k2=floor((C7(sum1+1)+1)/2);%互补级次
end



