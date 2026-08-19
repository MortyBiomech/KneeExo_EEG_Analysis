function [tfr, frequencies, times] = morlet_transform(signal, fs, freqs, width)
    % Input:
    % signal        - Input signal (1D array)
    % fs            - Sampling frequency (Hz)
    % freqs         - Array of target frequencies for the transform
    % wavelet_width - Wavelet width parameter (higher = more frequency resolution)
    %
    % Output:
    % tfr           - Time-frequency representation (frequency x time)
    % frequencies   - Array of frequencies used in the transform
    % times         - Time vector for the signal

    % Time vector for the signal
    N = length(signal);
    times = (0:N-1) / fs;

    % Initialize the time-frequency representation (TFR)
    tfr = zeros(length(freqs), N);

    t = -2 : 1/fs : 2;

    % Loop over all frequencies
    for f_idx = 1:length(freqs)
        % Current frequency
        f = freqs(f_idx);

        % Current width
        wavelet_width = width(f_idx);

        % Define the Morlet wavelet in the time domain
        morlet_wavelet = exp(1j * 2 * pi * f * t) .* exp(-t.^2 / (2 * (wavelet_width / f)^2));

        % Normalize the wavelet energy
        morlet_wavelet = morlet_wavelet / sqrt(sum(abs(morlet_wavelet).^2));

        % Perform convolution (FFT-based for efficiency)
        conv_result = conv(signal, morlet_wavelet, 'same');

        % Store the magnitude of the result (time-frequency representation)
        tfr(f_idx, :) = abs(conv_result).^2;
    end

    % Output the frequencies used
    frequencies = freqs;
end