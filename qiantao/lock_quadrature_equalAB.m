function [I1q,I2q,I3q,I4q] = lock_quadrature_equalAB(I1s,I2s,I3s,I4s,P,idealize)
[H,W] = size(I1s); x=0:W-1; w=2*pi/P; X=[cos(w*x(:)) sin(w*x(:)) ones(W,1)];
I1q=zeros(H,W); I2q=I1q; I3q=I1q; I4q=I1q;
for r=1:H
    b = X\I1s(r,:).'; a=b(1); c=b(2); d=b(3);
    A=hypot(a,c); phi=atan2(c,a); th=w*x-phi;
    if idealize, A=0.5; d=0.5; end
    I1q(r,:)=d+A*cos(th);
    I2q(r,:)=d+A*cos(th+pi/2);
    I3q(r,:)=d+A*cos(th+pi);
    I4q(r,:)=d+A*cos(th+3*pi/2);
end
end
