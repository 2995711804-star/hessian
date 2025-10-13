function P2 = refine_period_gls(I1,P0,mask)
[H,W] = size(I1); x=(0:W-1).'; rows=round(linspace(round(H*0.2),round(H*0.8),7));
if nargin<3||isempty(mask), mask=true(H,W); end
r=0.10; N=201; cand=linspace((1-r)*P0,(1+r)*P0,N);
best=inf; P2=P0;
for P=cand
    w=2*pi/P; Phi=[cos(w*x) sin(w*x) ones(W,1)]; SSE=0;
    for rr=rows
        y=I1(rr,:).'; mk=mask(rr,:).'; mk=mk&~isnan(y);
        if nnz(mk)<16, continue; end
        beta=Phi(mk,:)\y(mk); res=y(mk)-Phi(mk,:)*beta; SSE=SSE+sum(res.^2);
    end
    if SSE<best, best=SSE; P2=P; end
end
end
