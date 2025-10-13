function [row,score] = pick_best_row(I1raw,I1s,I2s,I3s,I4s,M,P,opt)
[H,~]=size(I1s);
if isnumeric(opt), row=max(1,min(H,round(opt))); score=NaN; return; end
s=lower(string(opt));
if s=="center", row=round(H/2); score=NaN; return; end
if s=="maxm", [~,row]=max(mean(M,2,'omitnan')); score=NaN; return; end
x=(0:size(I1s,2)-1).'; w=2*pi/P; Phi=[cos(w*x) sin(w*x) ones(numel(x),1)];
score=-inf; row=round(H/2); Iks={I1s,I2s,I3s,I4s};
for r=1:H
    mbar=mean(M(r,:),'omitnan');
    sat=mean(I1raw(r,:)>0.98 | I1raw(r,:)<0.02);
    y=I1s(r,:).'; b=Phi\y; yfit=Phi*b; thd=norm(y-yfit)/max(norm(yfit),eps);
    Ak=zeros(1,4);
    for k=1:4, yk=Iks{k}(r,:).'; bk=Phi\yk; Ak(k)=hypot(bk(1),bk(2)); end
    dev=std(Ak)/max(mean(Ak),eps);
    q=(mbar)/(thd+5e-3)*(1-min(dev,0.5))*(1-min(5*sat,0.9));
    if q>score, score=q; row=r; end
end
end
