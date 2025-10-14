::set HMGPATH to your HMG directory
SET HMGPATH=D:\hmg344

SET PATH=%HMGPATH%\harbour-64\bin;%HMGPATH%\mingw-64\bin;%PATH%

hbmk2 SumatraPDFLib.hbp -i%HMGPATH%\include -o%HMGPATH%\lib-64\SumatraPDF-64

pause
