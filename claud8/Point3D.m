function [Point] = Point3D(M,N,X,Y,Z) 

%排列数据
q=zeros(M*N,3);
for i=1:M
    for j=1:N
    q((i-1)*N+j,1)=X(i,j);
    q((i-1)*N+j,2)=Y(i,j);
    q((i-1)*N+j,3)=Z(i,j);
    end
end
%输出数据
Point=fopen('1.txt','w');
fprintf(Point,'%s\n','# .PCD v0.7 - Point Cloud Data file format','VERSION 0.7','FIELDS x y z','SIZE 4 4 4','TYPE F F F','COUNT 1 1 1','WIDTH 327680','HEIGHT 1','VIEWPOINT 0 0 0 1 0 0 0','POINTS 327680','DATA ascii');
fprintf(Point,'%d %d %d\n',q');
fclose(Point);

end