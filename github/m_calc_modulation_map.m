function difX = m_calc_modulation_map(files_phaseShift4)
assert(numel(files_phaseShift4)==4, '需要4幅相移图像');
I = cell(1,4);
for k=1:4
    Ik = im2double(imread(files_phaseShift4{k}));
    if size(Ik,3)>1, Ik = rgb2gray(Ik); end
    I{k} = Ik;
end
I1=I{1}; I2=I{2}; I3=I{3}; I4=I{4};
difX = 0.5 * sqrt( (I1 - I3).^2 + (I2 - I4).^2 );
end
