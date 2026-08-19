function tfdat = avedata(tfdat, dim, thresh, mode)
    tfsign  = sign(mean(tfdat,dim));
    tfmask  = sum(tfdat ~= 0,dim) >= thresh;
    if strcmpi(mode, 'rms')
        tfdat   = tfmask.*tfsign.*sqrt(mean(tfdat.*tfdat,dim)); % std of all channels
    else
        tfdat   = tfmask.*mean(tfdat,dim); % std of all channels
    end
end