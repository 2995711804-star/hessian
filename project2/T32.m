clear;
clc;

% % 00 标准正弦
x=-7.5:23.5;
y=0.5+0.5*sin((pi/16)*x+pi*3/2);
% 
% phase_row=repmat(y,1,32);
% phase=repmat(phase_row,1140,1);
% phase_crop=imcrop(phase,[1 1 911 1139]);
% imwrite(phase_crop,"C:\Users\ZiDongHua\Desktop\eq\12.bmp");
%% 01 第一张二值抖动
I1_part=zeros(1,32);

for i=1
    for j=1:32
        if y(j)>(1+sin((-4*pi)/16))/2
            I1_part(i,j)=(1+sin((-4*pi)/16))/2;
        else 
            I1_part(i,j)=y(j);
        end
    end
end

I1_row=repmat(I1_part,1,32);
I1=repmat(I1_row,1140,1);
s=size(I1);
outimage1=zeros(s(1),s(2));

for i=1:s(1)
    for j=1:s(2)
        if I1(i,j)<=(1+sin((-4*pi)/16))/4
                outimage1(i,j)=0;
                err=I1(i,j);
        else
                outimage1(i,j)=1;
                err=I1(i,j)-(1+sin((-4*pi)/16))/2;
        end
        if (j+1)<=s(2)
            I1(i,j+1)=I1(i,j+1)+7/16*err;
        end
        if ((i+1)<=s(1))&&((j-1)>=1)
            I1(i+1,j-1)=I1(i+1,j-1)+3/16*err;
        end
        if (i+1)<=s(1)
            I1(i+1,j)=I1(i+1,j)+5/16*err;
        end
        if ((i+1)<s(1))&&((j+1)<=s(2))
            I1(i+1,j+1)=I1(i+1,j+1)+1/16*err;
        end
    end
end

I1_crop=imcrop(outimage1,[1 1 911 1139]);
imshow(outimage1);
imwrite(I1_crop,'D:\shiyan\孙成师兄代码\1.bmp');

%% 02 第二张二值抖动
I2_part=zeros(1,32);

for i=1
    for j=1:32
        if y(j)<=(1+sin((-4*pi)/16))/2
            I2_part(i,j)=(1+sin((-4*pi)/16))/2;
        elseif y(j)>(1+sin((0*pi)/16))/2
            I2_part(i,j)=(1+sin((0*pi)/16))/2;
        else
            I2_part(i,j)=y(j);
        end
    end
end

I2_row=repmat(I2_part,1,32);
I2=repmat(I2_row,1140,1);
s=size(I2);
outimage2=zeros(s(1),s(2));

for i=1:s(1)
    for j=1:s(2)
        if I2(i,j)<=(((1+sin((0*pi)/16))-(1+sin((-4*pi)/16)))/4+(1+sin((-4*pi)/16)))/2
                outimage2(i,j)=0;
                err=I2(i,j)-(1+sin((-4*pi)/16))/2;
        else
                outimage2(i,j)=1;
                err=I2(i,j)-(1+sin((0*pi)/16))/2;
        end
        if (j+1)<=s(2)
            I2(i,j+1)=I2(i,j+1)+7/16*err;
        end
        if ((i+1)<=s(1))&&((j-1)>=1)
            I2(i+1,j-1)=I2(i+1,j-1)+3/16*err;
        end
        if (i+1)<=s(1)
            I2(i+1,j)=I2(i+1,j)+5/16*err;
        end
        if ((i+1)<s(1))&&((j+1)<=s(2))
            I2(i+1,j+1)=I2(i+1,j+1)+1/16*err;
        end
    end
end
I2_crop=imcrop(outimage2,[1 1 911 1139]);
imshow(outimage2);
imwrite(I2_crop,'D:\shiyan\孙成师兄代码\2.bmp');

% 03 第三张二值抖动
I3_part=zeros(1,32);

for i=1
    for j=1:32
        if y(j)<=(1+sin((0*pi)/16))/2
            I3_part(i,j)=(1+sin((0*pi)/16))/2;
        elseif y(j)>(1+sin((4*pi)/16))/2
            I3_part(i,j)=(1+sin((4*pi)/16))/2;
        else
            I3_part(i,j)=y(j);
        end
    end
end

I3_row=repmat(I3_part,1,32);
I3=repmat(I3_row,1140,1);

s=size(I3);
outimage3=zeros(s(1),s(2));

for i=1:s(1)
    for j=1:s(2)
        if I3(i,j)<=((1+sin((4*pi)/16))-(1+sin((0*pi)/16)))/4+(1+sin((0*pi)/16))/2
                outimage3(i,j)=0;
                err=I3(i,j)-(1+sin((0*pi)/16))/2;
        else
                outimage3(i,j)=1;
                err=I3(i,j)-(1+sin((4*pi)/16))/2;
        end
        if (j+1)<=s(2)
            I3(i,j+1)=I3(i,j+1)+7/16*err;
        end
        if ((i+1)<=s(1))&&((j-1)>=1)
            I3(i+1,j-1)=I3(i+1,j-1)+3/16*err;
        end
        if (i+1)<=s(1)
            I3(i+1,j)=I3(i+1,j)+5/16*err;
        end
        if ((i+1)<s(1))&&((j+1)<=s(2))
            I3(i+1,j+1)=I3(i+1,j+1)+1/16*err;
        end
    end
end
I3_crop=imcrop(outimage3,[1 1 911 1139]);
imshow(outimage3);
imwrite(I3_crop,'D:\shiyan\孙成师兄代码\3.bmp');

% 04 第四张二值抖动
I4_part=zeros(1,32);

for i=1
    for j=1:32
        if y(j)<=(1+sin((4*pi)/16))/2
            I4_part(i,j)=(1+sin((4*pi)/16))/2;
        else
            I4_part(i,j)=y(j);
        end
    end
end

I4_row=repmat(I4_part,1,32);
I4=repmat(I4_row,1140,1);

s=size(I4);
outimage4=zeros(s(1),s(2));

for i=1:s(1)
    for j=1:s(2)
        if I4(i,j)<=(2-(1+sin((4*pi)/16)))/4+(1+sin((4*pi)/16))/2
                outimage4(i,j)=0;
                err=I4(i,j)-(1+sin((4*pi)/16))/2;
        else
                outimage4(i,j)=1;
                err=I4(i,j)-1;
        end
        if (j+1)<=s(2)
            I4(i,j+1)=I4(i,j+1)+7/16*err;
        end
        if ((i+1)<=s(1))&&((j-1)>=1)
            I4(i+1,j-1)=I4(i+1,j-1)+3/16*err;
        end
        if (i+1)<=s(1)
            I4(i+1,j)=I4(i+1,j)+5/16*err;
        end
        if ((i+1)<s(1))&&((j+1)<=s(2))
            I4(i+1,j+1)=I4(i+1,j+1)+1/16*err;
        end
    end
end
I4_crop=imcrop(outimage4,[1 1 911 1139]);
imshow(outimage4);
imwrite(I4_crop,'D:\shiyan\孙成师兄代码\4.bmp'); 

I1=imread('D:\shiyan\孙成师兄代码\1.bmp');
I2=imread('D:\shiyan\孙成师兄代码\2.bmp');
I3=imread('D:\shiyan\孙成师兄代码\3.bmp');
I4=imread('D:\shiyan\孙成师兄代码\4.bmp');
I=((1+sin((-4*pi)/16))/2)*I1+((1+sin((0*pi)/16))/2-(1+sin((-4*pi)/16))/2)*I2+((1+sin((4*pi)/16))/2-(1+sin((0*pi)/16))/2)*I3+(1-(1+sin((4*pi)/16))/2)*I4;
imshow(I);
W = fspecial('gaussian',[5,5],5/3); 
B = imfilter(I, W, 'replicate');
% B=imgaussfilt(I,1);
imshow(B);
imwrite(B,'D:\shiyan\孙成师兄代码\5.bmp');

I=double(imread('D:\shiyan\孙成师兄代码\5.bmp'));
% x=zeros(1,132);
% for i=1:132
%         x(i)=i;
% end
% y=I(810,247:378);
% 
% I=double(imread('D:\shiyan\孙成师兄代码\6.bmp'));
% x=zeros(1,270);
% for i=1:270
%         x(i)=i;
% end
% y=I(810,247:516);
% 
% 
% I1=imread('D:\shiyan\孙成师兄代码\7.bmp');
% imshow(I1);
