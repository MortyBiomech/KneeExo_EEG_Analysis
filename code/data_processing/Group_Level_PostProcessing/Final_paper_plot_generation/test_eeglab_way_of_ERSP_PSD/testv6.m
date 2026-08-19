function v6 = testv6(x)

fid=fopen(x);
if fid == -1
    error('File %s not found - this could be because your STUDY contains data files with relative path, try changing your MATLAB path to the STUDY folder', x);
end
txt=char(fread(fid,20,'uchar')');
tmp = fclose(fid);
txt=[txt,char(0)];
txt=txt(1:find(txt==0,1,'first')-1);
if ~isempty(strfind(txt, 'MATLAB 5.0')), v6 = true; else v6 = false; end

end