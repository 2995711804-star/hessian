function [G1] = erzhihua(A,b)
    [H,W]=size(A);
    for i=1:H    
        for j=1:W
            if(b(i,j)>=A(i,j))  
                    G1(i,j)=1;
            elseif(b(i,j)<A(i,j))
                    G1(i,j)=0;
            end
        end
    end
end