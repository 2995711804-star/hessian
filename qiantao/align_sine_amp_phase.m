function [I1a,I2a,I3a,I4a] = align_sine_amp_phase(I1s,I2s,I3s,I4s,P)
[H,W] = size(I1s); w = 2*pi/P; x = 0:W-1; Phi = [cos(w*x(:)) sin(w*x(:)) ones(W,1)];
Iin={I1s,I2s,I3s,I4s}; Iout=cell(1,4);
for r=1:H
    B=zeros(4,3); for k=1:4, B(k,:)=(Phi\Iin{k}(r,:).').'; end
    a=B(:,1); b=B(:,2); c=B(:,3); A=hypot(a,b); phi=atan2(b,a);
    phi_ref=phi(1); phi_tgt=phi_ref+(0:3)'*pi/2; d=phi_tgt-phi;
    Acom=median(A); ccom=median(c);
    for k=1:4
        R=[cos(d(k)) -sin(d(k)); sin(d(k)) cos(d(k))]*[a(k);b(k)];
        a2=R(1)*(Acom/max(A(k),eps)); b2=R(2)*(Acom/max(A(k),eps));
        Iout{k}(r,:)=(Phi*[a2;b2;ccom]).';
    end
end
[I1a,I2a,I3a,I4a]=deal(Iout{:});
end

