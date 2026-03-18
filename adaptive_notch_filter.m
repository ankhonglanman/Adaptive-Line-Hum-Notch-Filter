%% ===================== THAM SỐ CHÍNH =====================
in_file = "cat_1.wav"
f0    = 50;        % Tần số hum
humAmp = 0.012;    % Biên độ nhiễu hum
nHarm = 3;         % Số hài của tín hiệu điện lưới cần loại bỏ
tlr = 1;         % Biên độ dao động của tần số (%)
% Tham số Fixed Notch Filter
Q = 40;            % Q factor
% Tham số Adaptive Notch
M     = 3;         % Bậc của bộ lọc 
mu    = 0.001;    % Bước học 
%% ===================== ĐỌC FILE LẤY TÍN HIỆU SẠCH & THÊM NHIỄU HUM =====================

[clean_signal, Fs] = audioread(in_file);    
clean_signal = clean_signal(:,1);               
N = length(clean_signal);                       
t = (0:N-1)'/Fs;      
min_fre = (100+tlr)*f0;
max_fre = (100+tlr)*f0;
for i = 1:N 
    random_fre(i, 1) = randi([min_fre, max_fre])/100;
end
hum = zeros(N, 1);
for k = 1:nHarm
    hum = hum + humAmp * (sin(2*pi*k*random_fre.*t) + cos(2*pi*k*random_fre.*t))/k ;
end
noisy_signal = clean_signal + hum;
noise = noisy_signal - clean_signal;
fre_noisy_signal = fft(noisy_signal);
SNR_in_dB = 10*log10(sum(clean_signal.^2)/sum(noise.^2));
fprintf('SNR trước lọc (Input SNR) = %.2f dB\n', SNR_in_dB);

%% ===================== FIXED NOTCH FILTER =====================

wo = f0/(Fs/2);         
bw = wo/Q;              
fixed_output = noisy_signal;
for k = 1:nHarm
    wok = k*wo;
    if wok >= 1, break; end
    bwk = wok/Q;                
    [b, a] = iirnotch(wok, bwk);
    fixed_output = filtfilt(b, a, fixed_output);
end
noise_fixed = fixed_output - clean_signal;
SNR_fixed_dB = 10*log10(sum(clean_signal.^2)/sum(noise_fixed.^2));
fre_fixed_output = fft(fixed_output);
fprintf('SNR sau fixed notch = %.2f dB\n', SNR_fixed_dB);

%% ===================== ADAPTIVE NOTCH FILTER (LMS) =====================

% Tín hiệu tham chiếu
ref_noise = zeros(N, 2*nHarm);
col = 1;
for k = 1:nHarm
    ref_noise(:, col) = sin(2*pi*k*random_fre.*t); col = col + 1;
    ref_noise(:, col) = cos(2*pi*k*random_fre.*t); col = col + 1;
end 
[hum_est, lms_output] = lms_adaptive_notch(noisy_signal, ref_noise, mu, M, nHarm); 
noise_lms = lms_output - clean_signal;
SNR_lms_dB = 10*log10(sum(clean_signal.^2)/sum(noise_lms.^2));
fre_lms_output = fft(lms_output);
fprintf('SNR sau adaptive notch (LMS) = %.2f dB\n', SNR_lms_dB);

%% ===================== SO SÁNH SNR =====================

diff_SNR_dB = SNR_lms_dB - SNR_fixed_dB;
fprintf('SNR cải thiện so với fixed notch filter = %.2f dB\n',diff_SNR_dB);
values = [SNR_in_dB, SNR_fixed_dB, SNR_lms_dB];
labels = {'Input', 'Fixed Notch', 'Adaptive LMS'};
figure;
bar(values);
set(gca, 'XTickLabel', labels);
for i = 1:length(values)
    text(i, values(i) - 1.5, sprintf('%.2f', values(i)), ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12);
end
ylabel('SNR (dB)');
title('So sánh chỉ số SNR');

%% ====================== VẼ PHỔ TÍN HIỆU =====================
f = Fs/N*(0:(N/2));
P2_noisy = abs(fre_noisy_signal/N);
P1_noisy = P2_noisy(1:N/2+1);
P1_noisy(2:end-1) = 2*P1_noisy(2:end-1);
P2_fixed = abs(fre_fixed_output/N);
P1_fixed = P2_fixed(1:N/2+1);
P1_fixed(2:end-1) = 2*P1_fixed(2:end-1);
P2_lms = abs(fre_lms_output/N);
P1_lms = P2_lms(1:N/2+1);
P1_lms(2:end-1) = 2*P1_lms(2:end-1);
figure;
subplot(3,1,1);
plot(f, P1_noisy);
title('Tín hiệu bị nhiễu');
xlabel('Tần số (Hz)'); ylabel('Biên độ');
xlim([0 200]);
subplot(3,1,2);
plot(f, P1_fixed);
title('Tín hiệu sau fixed notch');
xlabel('Tần số (Hz)'); ylabel('Biên độ');
xlim([0 200]);
subplot(3,1,3);
plot(f, P1_lms);
title('Tín hiệu sau adaptive notch (LMS)');
xlabel('Tần số (Hz)'); ylabel('Biên độ');
xlim([0 200]);
