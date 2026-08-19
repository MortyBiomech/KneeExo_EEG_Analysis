function filebase = getfilename(filepath, subj, sess, fileSuffix, onlyOneSession)
if onlyOneSession
    filebase = fullfile(filepath, [ subj fileSuffix ] );
else
    sesStr   = [ '0' sess ];
    filebase = fullfile(filepath, [ subj '_ses-' sesStr(end-1:end) fileSuffix ] );
end