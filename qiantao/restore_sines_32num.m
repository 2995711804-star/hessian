function [I1,I2,I3,I4,info] = restore_sines_32num(imgdir, varargin)
% 32 连号帧 → 四步正弦（正弦化 / 等幅+相位对齐 / 严格四步）+ 自动选最佳行
% 极简稳健版（配合外部子函数文件使用）

%% 参数
p = inputParser;
p.addParameter('coding','gray', @(s)ischar(s)||isstring(s));
p.addParameter('gamma_cam',2.2, @(x)isnumeric(x)&&isscalar(x));
p.addParameter('median3',true,  @islogical);
p.addParameter('visualize',true,@islogical);
p.addParameter('save_dir','',   @(s)ischar(s)||isstring(s));
p.addParameter('enforce_sine',true,@islogical);
p.addParameter('align_sine',true,@islogical);
p.addParameter('lock_quadrature',true,@islogical);
p.addParameter('idealize',false,@islogical);
p.addParameter('ultra_sine',true,@islogical);
p.addParameter('clip',[0.12 0.88],@(v)isnumeric(v)&&numel(v)==2&&v(1)<v(2));
p.addParameter('period_px',[], @(x) isempty(x) || (isscalar(x)&&x>0));
p.addParameter('period_refine',true,@islogical);
p.addParameter('smooth_y_sigma',1.5,@(x)isnumeric(x)&&isscalar(x)&&x>=0);
p.addParameter('plot_row','best', @(x)ischar(x)||isstring(x)||(isnumeric(x)&&isscalar(x)));
p.addParameter('metrics_csv','metrics.csv',@(s)ischar(s)||isstring(s));
p.parse(varargin{:});

coding      = lower(string(p.Results.coding));
gamma_cam   = p.Results.gamma_cam;
use_med     = p.Results.median3;
viz         = p.Results.visualize;
save_dir    = string(p.Results.save_dir);
do_enforce  = p.Results.enforce_sine;
do_align    = p.Results.align_sine;
do_quad     = p.Results.lock_quadrature;
do_ideal    = p.Results.idealize;
ultra       = p.Results.ultra_sine;
clip        = p.Results.clip;
period_px   = p.Results.period_px;
do_refine   = p.Results.period_refine;
sigmaY      = p.Results.smooth_y_sigma;
plot_row_opt= p.Results.plot_row;
metrics_csv = string(p.Results.metrics_csv);

assert(isfolder(imgdir),'目录不存在：%s',imgdir);

if ultra
    gamma_cam  = 2.2;
    use_med    = true;
    do_enforce = true;
    do_align   = true;
    do_quad    = true;
    clip       = [0.12 0.88];
end

%% 读取 32 帧
exts = {'.bmp','.png','.jpg','.jpeg','.tif','.tiff','.BMP','.PNG','.JPG','.JPEG','.TIF','.TIFF'};
files = strings(32,1);
for i = 1:32
    got = "";
    for e = 1:numel(exts)
        f = fullfile(imgdir, sprintf('%d%s',i,exts{e}));
        if isfile(f), got = string(f); break; end
    end
    if got=="", error('缺少文件：%s', fullfile(imgdir, sprintf('%d.*',i))); end
    files(i) = got;
end

I0 = imread(files(1)); if size(I0,3)==3, I0 = rgb2gray(I0); end
[H,W] = size(I0);
C = zeros(H,W,32);
for i = 1:32
    t = imread(files(i)); if size(t,3)==3, t = rgb2gray(t); end
    t = im2double(t);
    if gamma_cam~=1, t = t.^gamma_cam; end
    C(:,:,i) = t;
end

%% 复原四幅（遍历 四组合×两位序）
orders = cell(2,1);
for k=1:4, orders{1}{k}=(k-1)*8+(1:8); orders{2}{k}=k+(0:7)*4; end
bit_orders = {1:8, 8:-1:1}; tags={'连续+MSB','连续+LSB','交错+MSB','交错+LSB'};
best.meanM=-inf; best.tag="";

cid=0;
for oi=1:2
  for bi=1:2
    cid=cid+1;
    I = zeros(H,W,4);
    for k=1:4
        idx8 = orders{oi}{k}(bit_orders{bi});
        stack = C(:,:,idx8);
        thr = 0.5*(max(stack,[],3)+min(stack,[],3));
        bits = false(H,W,8);
        for bb=1:8
            plane = stack(:,:,bb)>thr;
            if use_med, plane = medfilt2(plane,[3 3],'symmetric'); end
            bits(:,:,bb)=plane;
        end
        if coding=="gray"
            b = false(H,W,8); b(:,:,1)=bits(:,:,1);
            for jj=2:8, b(:,:,jj)=xor(b(:,:,jj-1),bits(:,:,jj)); end
        else
            b = bits;
        end
        val = zeros(H,W,'uint16');
        for jj=1:8
            val = val + uint16(b(:,:,jj))*uint16(2^(8-jj));
        end
        I(:,:,k)=double(val)/255;
    end
    M = 0.5*sqrt((I(:,:,4)-I(:,:,2)).^2 + (I(:,:,1)-I(:,:,3)).^2);
    mM = mean(M(:),'omitnan');
    if mM>best.meanM
        best.meanM=mM; best.I=I; best.M=M; best.tag=tags{cid};
    end
  end
end

I1=best.I(:,:,1); I2=best.I(:,:,2); I3=best.I(:,:,3); I4=best.I(:,:,4);

%% 周期估计 + 精炼
if isempty(period_px)
    row0 = round(H/2);
    y = I1(row0,:)-mean(I1(row0,:));
    Y = abs(fft(y)); Y(1)=0; K = floor(numel(Y)/2);
    [~,k0] = max(Y(1:K));
    period_px = numel(y)/k0;
end
if do_refine
    period_px = refine_period_gls(I1,period_px,best.M>0.2); % 外部文件
end

%% 正弦化
I1s=I1; I2s=I2; I3s=I3; I4s=I4;
if do_enforce
    [I1s,I2s,I3s,I4s,statS] = enforce_sinusoid_per_row(I1,I2,I3,I4,period_px,clip); % 外部文件
else
    statS.M_before_mean = mean(best.M(:),'omitnan');
    statS.M_after_mean  = statS.M_before_mean;
end
% ★ 方案A：把这两个值写进 info（后面构建 info 时会带上）
info_M_before = statS.M_before_mean;
info_M_after  = statS.M_after_mean;

M_sine = 0.5*sqrt((I4s-I2s).^2 + (I1s-I3s).^2);

%% 选“最佳行”
[best_row,best_score] = pick_best_row(I1,I1s,I2s,I3s,I4s,M_sine,period_px,plot_row_opt); % 外部文件

%% 指标（同一行）
met_sine  = calc_metrics(I1s,I2s,I3s,I4s,period_px,M_sine,best_row); % 外部文件
if do_align
    [I1a,I2a,I3a,I4a] = align_sine_amp_phase(I1s,I2s,I3s,I4s,period_px); % 外部文件
    M_align = 0.5*sqrt((I4a-I2a).^2 + (I1a-I3a).^2);
    met_align = calc_metrics(I1a,I2a,I3a,I4a,period_px,M_align,best_row);
else
    I1a=[];I2a=[];I3a=[];I4a=[]; met_align=[];
end
if do_quad
    if do_align
        [I1q,I2q,I3q,I4q] = lock_quadrature_equalAB(I1a,I2a,I3a,I4a,period_px,do_ideal); % 外部文件
        M_quad = 0.5*sqrt((I4q-I2q).^2 + (I1q-I3q).^2);
        met_quad = calc_metrics(I1q,I2q,I3q,I4q,period_px,M_quad,best_row);
    else
        [I1q,I2q,I3q,I4q] = lock_quadrature_equalAB(I1s,I2s,I3s,I4s,period_px,do_ideal);
        M_quad = 0.5*sqrt((I4q-I2q).^2 + (I1q-I3q).^2);
        met_quad = calc_metrics(I1q,I2q,I3q,I4q,period_px,M_quad,best_row);
    end
else
    I1q=[];I2q=[];I3q=[];I4q=[]; met_quad=[];
end

%% 竖向轻平滑（不改横向）
if sigmaY>0
    ky = fspecial('gaussian',[max(3,ceil(6*sigmaY)) 1], sigmaY);
    I1s=imfilter(I1s,ky,'replicate'); I2s=imfilter(I2s,ky,'replicate');
    I3s=imfilter(I3s,ky,'replicate'); I4s=imfilter(I4s,ky,'replicate');
    if ~isempty(I1a)
        I1a=imfilter(I1a,ky,'replicate'); I2a=imfilter(I2a,ky,'replicate');
        I3a=imfilter(I3a,ky,'replicate'); I4a=imfilter(I4a,ky,'replicate');
    end
    if ~isempty(I1q)
        I1q=imfilter(I1q,ky,'replicate'); I2q=imfilter(I2q,ky,'replicate');
        I3q=imfilter(I3q,ky,'replicate'); I4q=imfilter(I4q,ky,'replicate');
    end
end

%% 可视化（都用同一行 best_row）
if viz
    figure('Name','原始 I1..I4'); clf;
    subplot(2,2,1); imagesc(I1); axis image off; colormap gray; colorbar; title('I1'); caxis([0 1]);
    subplot(2,2,2); imagesc(I2); axis image off; colormap gray; colorbar; title('I2'); caxis([0 1]);
    subplot(2,2,3); imagesc(I3); axis image off; colormap gray; colorbar; title('I3'); caxis([0 1]);
    subplot(2,2,4); imagesc(I4); axis image off; colormap gray; colorbar; title('I4'); caxis([0 1]);

    figure('Name','正弦化 I1..I4'); clf;
    subplot(2,2,1); imagesc(I1s); axis image off; colormap gray; colorbar; title('I1 (sine)'); caxis([0 1]);
    subplot(2,2,2); imagesc(I2s); axis image off; colormap gray; colorbar; title('I2 (sine)'); caxis([0 1]);
    subplot(2,2,3); imagesc(I3s); axis image off; colormap gray; colorbar; title('I3 (sine)'); caxis([0 1]);
    subplot(2,2,4); imagesc(I4s); axis image off; colormap gray; colorbar; title('I4 (sine)'); caxis([0 1]);

    if ~isempty(I1a)
        figure('Name','等幅+相位对齐 I1..I4'); clf;
        subplot(2,2,1); imagesc(I1a); axis image off; colormap gray; colorbar; title('I1 (align)'); caxis([0 1]);
        subplot(2,2,2); imagesc(I2a); axis image off; colormap gray; colorbar; title('I2 (align)'); caxis([0 1]);
        subplot(2,2,3); imagesc(I3a); axis image off; colormap gray; colorbar; title('I3 (align)'); caxis([0 1]);
        subplot(2,2,4); imagesc(I4a); axis image off; colormap gray; colorbar; title('I4 (align)'); caxis([0 1]);

        row = best_row;
        figure('Name','正弦化 vs 对齐（I1 剖面）'); plot(I1s(row,:)); hold on; plot(I1a(row,:),'LineWidth',1.2); grid on
        legend('正弦化','等幅+相位对齐'); title(sprintf('Row %d | period=%.2f px',row,period_px));
    end

    if ~isempty(I1q)
        row = best_row;
        figure('Name','对齐/正弦化 vs 严格四步（I1 剖面）'); 
        if ~isempty(I1a), plot(I1a(row,:)); hold on; else, plot(I1s(row,:)); hold on; end
        plot(I1q(row,:),'LineWidth',1.2); grid on
        legend('对齐/正弦化','严格四步'); title(sprintf('Row %d | period=%.2f px',row,period_px));
    end

    figure('Name',sprintf('调制度 M | 方案：%s',best.tag));
    imagesc(best.M); axis image off; colormap gray; colorbar;
end

%% 输出 info（★ 把 M_before/M_after 写进去）
info = struct();
info.scheme       = best.tag;
info.sizeHW       = [H W];
info.meanM        = mean(best.M(:),'omitnan');
info.period_px    = period_px;
info.plot_row     = best_row;
info.row_score    = best_score;
info.M_before_mean= info_M_before;   % ★ from statS
info.M_after_mean = info_M_after;    % ★ from statS
info.metrics_sine = met_sine;
if ~isempty(met_align), info.metrics_align = met_align; end
if ~isempty(met_quad),  info.metrics_quad  = met_quad;  end

%% 保存（含 CSV；依赖 struct2table_with_mode.m）
if strlength(save_dir)>0
    if ~isfolder(save_dir), mkdir(save_dir); end
    imwrite(uint8(round(I1*255)), fullfile(save_dir,'I1_rec.bmp'));
    imwrite(uint8(round(I2*255)), fullfile(save_dir,'I2_rec.bmp'));
    imwrite(uint8(round(I3*255)), fullfile(save_dir,'I3_rec.bmp'));
    imwrite(uint8(round(I4*255)), fullfile(save_dir,'I4_rec.bmp'));
    imwrite(uint8(round(I1s*255)),fullfile(save_dir,'I1_rec_sine.bmp'));
    imwrite(uint8(round(I2s*255)),fullfile(save_dir,'I2_rec_sine.bmp'));
    imwrite(uint8(round(I3s*255)),fullfile(save_dir,'I3_rec_sine.bmp'));
    imwrite(uint8(round(I4s*255)),fullfile(save_dir,'I4_rec_sine.bmp'));
    if ~isempty(I1a)
        imwrite(uint8(round(I1a*255)),fullfile(save_dir,'I1_rec_align.bmp'));
        imwrite(uint8(round(I2a*255)),fullfile(save_dir,'I2_rec_align.bmp'));
        imwrite(uint8(round(I3a*255)),fullfile(save_dir,'I3_rec_align.bmp'));
        imwrite(uint8(round(I4a*255)),fullfile(save_dir,'I4_rec_align.bmp'));
    end
    if ~isempty(I1q)
        imwrite(uint8(round(I1q*255)),fullfile(save_dir,'I1_rec_quad.bmp'));
        imwrite(uint8(round(I2q*255)),fullfile(save_dir,'I2_rec_quad.bmp'));
        imwrite(uint8(round(I3q*255)),fullfile(save_dir,'I3_rec_quad.bmp'));
        imwrite(uint8(round(I4q*255)),fullfile(save_dir,'I4_rec_quad.bmp'));
    end

    if strlength(metrics_csv)>0 && exist('struct2table_with_mode','file')==2
        csvfile = fullfile(save_dir, metrics_csv);
        T = struct2table_with_mode(met_sine, info, "sine");
        if exist(csvfile,'file'), writetable(T,csvfile,'WriteMode','append'); else, writetable(T,csvfile); end
        if ~isempty(met_align), T = struct2table_with_mode(met_align, info, "align"); writetable(T,csvfile,'WriteMode','append'); end
        if ~isempty(met_quad),  T = struct2table_with_mode(met_quad,  info, "quad");  writetable(T,csvfile,'WriteMode','append'); end
    end
end
end
% clear; close all; clc;
% addpath('C:\Users\PC\Desktop\new1\pic\1');   % ← 改成你保存 .m 文件的文件夹
% 
% imgdir = "C:\Users\PC\Desktop\new1\pic\1";
% 
% [I1,I2,I3,I4,info] = restore_sines_32num(imgdir, ...
%   'ultra_sine',true, 'idealize',false, ...
%   'period_px',45.7, 'period_refine',true, ...
%   'align_sine',true, ...
%   'clip',[0.10 0.90], ...        % ← 放宽端点剔除，提升有效点数/覆盖率
%   'smooth_y_sigma',1.0, ...      % ← 轻一点的竖向平滑
%   'plot_row','best', ...
%   'visualize',true, ...
%   'save_dir',fullfile(imgdir,'recovered'), ...
%   'metrics_csv','metrics.csv');
% 
% % 查看指标（现在会多出 coverage_adapt_p30 与 th_adapt）
% disp(info.plot_row);          
% disp(info.row_score);         
% disp(info.metrics_sine);
% if isfield(info,'metrics_align'), disp(info.metrics_align); end
% if isfield(info,'metrics_quad'),  disp(info.metrics_quad);  end
% 
% % Windows 下直接打开输出文件夹
% winopen(fullfile(imgdir,'recovered'));
