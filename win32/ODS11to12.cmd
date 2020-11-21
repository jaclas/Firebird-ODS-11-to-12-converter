@echo off
if "%1"=="" (
 echo error!
 echo The input database file name ^(in ODS11 format^) is not provided
 echo.
 goto showusage
)
if not exist "%1" (
 echo error!
 echo File %1 has not been found!
 goto finished
)
if "%2"=="" (
 echo error!
 echo The file name of the RESULTING database file is not provided
 echo.
 goto showusage
)
if %1==%2 (
 echo error!
 echo Both parameters indicate the same file!
 goto finished
)
if exist "%2" (
 echo error!
 echo File %2 exists on the disk, give the name of a non-existent file
 goto finished
)
set ISC_USER=SYSDBA
if exist "*.log" (
echo.
echo I delete old logs...
del *.log
)
echo.
echo I start converting the database structure...
echo.
echo %1 (ODS11) =^> %2 (ODS12)
echo.
echo Please wait, depending on the size of the input database, this may take several minutes...

fb25\gbak -z -b -g -t -v -st t -y backup_25.log %1 stdout|^
fb30\gbak -z -c -v -st t -y restore_30.log stdin %2

IF %ERRORLEVEL% NEQ 0 ( 
   echo.
   echo Something went wrong during the database conversion! See to logs: backup_25.log and/or restore_30.log
   goto finished
)

echo.
echo Successful conversion of the Firebird database structure!
echo New database file is: %2
exit /B 0

:showusage
echo --------------------------------------
echo ^|    FIREBIRD ODS 11/12 CONVERTER    ^|
echo ^|             by JL (@2020)          ^|
echo --------------------------------------
echo.
echo The syntax for converting the database from ODS11 to ODS12 is as follows:
echo.
echo ODS11to12.cmd dbfile_ODS11.fdb dbfile_ODS12.fdb
echo.
echo where:
echo.
echo dbfile_ODS11.fdb - is the name of the database file to be converted, compatible with ODS11 format
echo.
echo dbfile_ODS12.fdb - is the name of the new file, where the database will be saved in ODS12 format
exit /B 1

:finished
EXIT /B %ERRORLEVEL%