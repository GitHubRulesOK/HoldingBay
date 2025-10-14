::set HMGPATH to your HMG directory
SET HMGPATH=D:\hmg344

SET PATH=%HMGPATH%\harbour\bin;%HMGPATH%\mingw\bin;%PATH%

hbmk2 SumatraPDFLib.hbp -i%HMGPATH%\include -o%HMGPATH%\lib\SumatraPDF

pause
