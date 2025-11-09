%% ===================== THAM SỐ CHÍNH =====================

f0    = 50;        % Tần số hum điện lưới ở Việt Nam , thay bằng 60hz nếu muốn
humAmp = 0.015;    % Biên độ nhiễu hum, tùy chỉnh để thay đổi chỉ số SNR của tín hiệu bị nhiễu

% Tham số Fixed Notch Filter
Q = 35;            % Q càng lớn thì băng dải càng hẹp

% Tham số LMS
M     = 3;         % Bậc của bộ lọc (hay số input cần dùng trong mỗi bước lặp, gồm input hiện tại và (M - 1) input trước đó
mu    = 0.0001;    % Bước học 

%% ===================== ĐỌC FILE LẤY TÍN HIỆU SẠCH & THÊM NHIỄU HUM =====================

% Tín hiệu sạch đọc từ file âm thanh 
[clean_signal, Fs] = audioread("cat_1.wav");    % Đọc file âm thanh bất kỳ
clean_signal = clean_signal(:,1);               % Chỉ lấy 1 kênh nếu tín hiệu là stereo
N = length(clean_signal);                       % Số lượng mẫu lấy ra từ file âm thanh ban đầu
t = (0:N-1)'/Fs;                                % Mảng chứa các thời điểm lấy mẫu

% Nhiễu hum 
hum = humAmp * (sin(2*pi*f0*t) + cos(2*pi*f0*t));

% --- Sử dụng đoạn này để thêm các sóng hài bậc 2, 3, ... với biên độ giảm dần
% hum = humAmp * (sin(2*pi*f0*t) + 0.5*sin(2*pi*2*f0*t) + 0.3*sin(2*pi*3*f0*t));

% --- Sử dụng đoạn này để tạo hum từ tần số điện lưới thay đổi +- 2.5hz 
%min_fre = 100*f0-25;
%max_fre = 100*f0+25;
%for i = 1:N 
%    random_fre(i, 1) = randi([min_fre, max_fre])/10;
%end
%hum = humAmp * sin(2*pi*random_fre.*t) ;

% Tín hiệu bị nhiễu
noisy_signal = clean_signal + hum;

% SNR đầu vào 
SNR_in_dB = 10*log10(sum(clean_signal.^2)/sum(hum.^2));
fprintf('SNR trước lọc (Input SNR) = %.2f dB\n', SNR_in_dB);

%% ===================== FIXED NOTCH FILTER =====================

% Thiết kế bộ lọc notch IIR cố định tại tần số f0
wo = f0/(Fs/2);         % Tần số bị lọc mất chuẩn hoá với Fs/2 scale thành 1
bw = wo/Q;              % Băng thông 
[b_notch, a_notch] = iirnotch(wo, bw);

% --- Sử dụng phần này để lọc bỏ tín hiệu nhiễu hum hài bậc 2,3 
%[b_notch, a_notch] = iirnotch(2*wo, bw);
%[b_notch, a_notch] = iirnotch(3*wo, bw);

% Lọc bằng notch filter
fixed_output = filter(b_notch, a_notch, noisy_signal);

% Tính SNR sau khi lọc bằng fixed notch
noise_fixed = fixed_output - clean_signal;
SNR_fixed_dB = 10*log10(sum(clean_signal.^2)/sum(noise_fixed.^2));

fprintf('SNR sau fixed notch = %.2f dB\n', SNR_fixed_dB);

%% ===================== ADAPTIVE NOTCH FILTER (LMS) =====================

% Tín hiệu tham chiếu hum (giả sử đo được từ lưới)
ref_noise = sin(2*pi*f0*t) + cos(2*pi*f0*t);   

% Gọi hàm LMS adaptive notch (ANC)
[hum_est, lms_output, w_hist] = lms_adaptive_notch(noisy_signal, ref_noise, mu, M);

% lms_output là e(n): ước lượng tín hiệu sạch
noise_lms = lms_output - clean_signal;
SNR_lms_dB = 10*log10(sum(clean_signal.^2)/sum(noise_lms.^2));
fprintf('SNR sau adaptive notch (LMS) = %.2f dB\n', SNR_lms_dB);

%% ===================== SO SÁNH SNR =====================

diff_SNR_dB = SNR_lms_dB - SNR_fixed_dB;
fprintf('SNR cải thiện so với fixed notch filter = %.2f dB\n',diff_SNR_dB);
figure;
bar([SNR_in_dB, SNR_fixed_dB, SNR_lms_dB]);
set(gca, 'XTickLabel', {'Input', 'Fixed Notch', 'Adaptive LMS'});
ylabel('SNR (dB)');
title('So sánh SNR: Input vs Fixed Notch vs Adaptive LMS');
grid on;

%% ===================== VẼ TÍN HIỆU THEO THỜI GIAN =====================

figure;
subplot(3,1,1);
plot(t, noisy_signal);
title('Tín hiệu bị nhiễu (noisy)');
xlabel('Thời gian (s)'); ylabel('Biên độ');

subplot(3,1,2);
plot(t, fixed_output);
title('Tín hiệu sau fixed notch');

subplot(3,1,3);
plot(t, lms_output);
title('Tín hiệu sau adaptive notch (LMS)');
xlabel('Thời gian (s)'); ylabel('Biên độ');

%% ===================== HÀM LMS ADAPTIVE NOTCH =====================
% d(n)      : tín hiệu bị nhiễu (clean + hum)
% x_ref(n)  : nhiễu tham chiếu hum
% y(n)      : nhiễu ước lượng = w^T x(n)
% e(n)      : sai số = d(n) - y(n) ≈ tín hiệu sạch
% w(n+1)    : w(n) + 2 * mu * e(n) * x(n)

function [y_est, e, w_hist] = lms_adaptive_notch(d, x_ref, mu, M)
    % d     : tín hiệu bị nhiễu (vector cột)
    % x_ref : nhiễu tham chiếu (vector cột)
    % mu    : bước học
    % M     : số tap của bộ lọc LMS
    %
    % y_est : ước lượng nhiễu hum
    % e     : đầu ra lỗi (xấp xỉ tín hiệu sạch sau lọc)
    % w_hist: lịch sử trọng số w (M x N)

    N = length(d);
    d = d(:);         % đảm bảo dạng cột
    x_ref = x_ref(:); % đảm bảo dạng cột

    w = zeros(M,1);            % trọng số ban đầu
    w_hist = zeros(M,N);       % lưu lịch sử trọng số
    y_est = zeros(N,1);        % nhiễu ước lượng
    e     = zeros(N,1);        % sai số (tín hiệu sạch ước lượng)

    for n = M:N
        % Vector đầu vào x(n) = [x_ref(n), x_ref(n-1), ..., x_ref(n-M+1)]^T
        x = x_ref(n:-1:n-M+1);   % Mx1
        % Đầu ra bộ lọc (nhiễu ước lượng)
        y_est(n) = w.' * x;
        % Sai số giữa tín hiệu bị nhiễu và nhiễu ước lượng
        e(n) = d(n) - y_est(n);
        % Cập nhật trọng số LMS
        w = w + 2*mu*e(n)*x;
        % Lưu lại
        w_hist(:,n) = w;
    end
end
