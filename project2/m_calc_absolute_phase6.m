function [pha_absolute, dif] = m_calc_absolute_phase6(files_phaseShift, files_grayCode, IT, B_min, win_size)
[~, N] = size(files_phaseShift);
[pha_wrapped, B] = m_calc_warppred_phase6(files_phaseShift, N);

[~, n] = size(files_grayCode);
n = n - 2;  % 投影了一黑一白两幅图片

Ks = m_calc_gray_code(files_grayCode, IT, n-1);
Ks1 = m_calc_gray_code(files_grayCode, IT, n);
for i=1:1024
    for j=1:1280
        if(pha_wrapped(i,j)<=pi/2)
            pha_absolute(i,j)=pha_wrapped(i,j)+2*pi*floor((Ks1(i,j)+1)/2);
        elseif(pi/2<pha_wrapped(i,j)&&pha_wrapped(i,j)<3*pi/2)
            pha_absolute(i,j)=pha_wrapped(i,j)+2*pi*Ks(i,j);
        elseif(3*pi/2<=pha_wrapped(i,j))
            pha_absolute(i,j)=pha_wrapped(i,j)+2*pi*floor((Ks1(i,j)+1)/2)-2*pi;
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
pha_absolute = pha_absolute / (2 * pi * 28.5);


end