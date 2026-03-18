%% ===================== HÀM LMS ADAPTIVE NOTCH =====================
function [y_est, notch_output] = lms_adaptive_notch(d, X, mu, M, nHarm)
    N = length(d);
    d = d(:); 
    w = zeros(M,1);   
    y_est = zeros(N,2*nHarm);        
    e     = zeros(N,1); 
    notch_output = d;
    for k = 1:2*nHarm
        x_ref = X(:, k);        
        for n = M:N
            x = x_ref(n:-1:n-M+1);  
            y_est(n, k) = w.' * x;
            e(n) = d(n) - y_est(n, k);
            w = w + 2*mu*e(n)*x;
        end
        notch_output = notch_output - y_est(:, k);
    end
end