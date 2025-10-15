function [pha_absolute, dif] = m_calc_absolute_phase1(files_phaseShift, files_grayCode, IT, B_min, win_size)
[~, N] = size(files_phaseShift);
[pha_wrapped, B] = m_calc_warppred_phase(files_phaseShift, N);

[~, n] = size(files_grayCode);
n = n - 2;  % 投影了一黑一白两幅图片

% Ks = m_calc_gray_code(files_grayCode, IT, n-1);
% Ks1 = m_calc_gray_code(files_grayCode, IT, n);
%[k1,k2] = m_calc_gray_code111111(files_grayCode, IT, n);
[k1,k2] = m_calc_gray_code111111(files_grayCode);


img = imread(files_grayCode{1});
[h, w] = size(img);
pha_absolute=zeros(h,w);
for i=1:h
    for j=1:w
        if(pha_wrapped(i,j)<2*pi/4)
            pha_absolute(i,j)=pha_wrapped(i,j)+2*pi*(k2(i,j));
        elseif(pha_wrapped(i,j)>=2*pi/4&&pha_wrapped(i,j)<3*pi/2)
            pha_absolute(i,j)=pha_wrapped(i,j)+2*pi*(k1(i,j));
        elseif(pha_wrapped(i,j)>=3*pi/2)
            pha_absolute(i,j)=pha_wrapped(i,j)+2*pi*(k2(i,j)-1);
        end        
    end
end

% pha_absolute = pha_wrapped + 2 * pi .* Ks;

% 调制度滤波
B_mask = B > B_min;
pha_absolute = pha_absolute .* B_mask;

% 边缘跳变误差
[pha_absolute, dif] = m_filter2d(pha_absolute, win_size);

% 归一化
pha_absolute = pha_absolute / (2 * pi *57);
[h,w]=size(pha_absolute);
%输出一个截断相位图片
A1=pha_absolute;
for i=1:h
    for j=1:w
        if(A1(i,j)>0)
            A1(i,j)=1;
        end
    end
end
for i=1:h
    for j=1:w
        B1(i,j)=A1(i,j)*pha_wrapped(i,j);
    end
end
imwrite(mat2gray(B1),'相位主值.bmp');


end