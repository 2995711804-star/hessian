% �˲�
function [pha_new, dif] = m_filter2d(pha, win_size)
% ��ֵ�˲����������Ե������������⣩
pha_new = medfilt2(pha, [win_size, win_size]);

% ���޳�δ��������
dif = pha - pha_new;
end

