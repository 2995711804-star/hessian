function [pphase] = unwrapping(phase,n,n1,M,N)
%UNTITLED7 此处显示有关此函数的摘要
%   此处显示详细说明
pphase=zeros(M,N);
for i=1:M
    for j=1:N
        if(phase(i,j)<=-pi/2)
            pphase(i,j)=phase(i,j)+2*pi*floor((n1(i,j)+1)/2);
        elseif(-pi/2<phase(i,j)&&phase(i,j)<pi/2)
            pphase(i,j)=phase(i,j)+2*pi*n(i,j);
        elseif(pi/2<=phase(i,j))
            pphase(i,j)=phase(i,j)+2*pi*floor((n1(i,j)+1)/2)-2*pi;
        end
    end
end
end

