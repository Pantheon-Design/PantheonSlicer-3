SET START_TIME=%TIME%

set WP=%CD%

set debug=OFF
set debuginfo=OFF
if "%1"=="debug" set debug=ON
if "%2"=="debug" set debug=ON
if "%1"=="debuginfo" set debuginfo=ON
if "%2"=="debuginfo" set debuginfo=ON
if "%debug%"=="ON" (
    set build_type=Debug
    set build_dir=build-dbg
) else (
    if "%debuginfo%"=="ON" (
        set build_type=RelWithDebInfo
        set build_dir=build-dbginfo
    ) else (
        set build_type=Release
        set build_dir=build
    )
)
echo build type set to %build_type%

cd deps
mkdir %build_dir%
cd %build_dir%
set DEPS=%CD%/PantheonSlicer_dep
if "%1"=="slicer" (
    GOTO :slicer
)
echo "building deps.."

@REM echo cmake ../ -G "Visual Studio 16 2019" -A x64 -DDESTDIR="%CD%/PantheonSlicer_dep" -DCMAKE_BUILD_TYPE=%build_type% -DDEP_DEBUG=%debug% -DORCA_INCLUDE_DEBUG_INFO=%debuginfo%
@REM cmake ../ -G "Visual Studio 16 2019" -A x64 -DDESTDIR="%CD%/PantheonSlicer_dep" -DCMAKE_BUILD_TYPE=%build_type% -DDEP_DEBUG=%debug% -DORCA_INCLUDE_DEBUG_INFO=%debuginfo%
@REM cmake --build . --config %build_type% --target deps -- -m

if "%1"=="deps" exit /b 0

:slicer
echo "building Orca Slicer..."
cd %WP%
mkdir %build_dir%
cd %build_dir%

echo cmake .. -G "Visual Studio 16 2019" -A x64 -DBBL_RELEASE_TO_PUBLIC=1 -DCMAKE_PREFIX_PATH="%DEPS%/usr/local" -DCMAKE_INSTALL_PREFIX="./PantheonSlicer-3" -DCMAKE_BUILD_TYPE=%build_type%
cmake .. -G "Visual Studio 16 2019" -A x64 -DBBL_RELEASE_TO_PUBLIC=1 -DCMAKE_PREFIX_PATH="%DEPS%/usr/local" -DCMAKE_INSTALL_PREFIX="./PantheonSlicer-3" -DCMAKE_BUILD_TYPE=%build_type% -DWIN10SDK_PATH="C:/Program Files (x86)/Windows Kits/10/Include/10.0.19041.0"
cmake --build . --config %build_type% --target ALL_BUILD -- -m
cd ..
call run_gettext.bat
cd %build_dir%
cmake --build . --target install --config %build_type%


CALL :DIFF_TIME ELAPSED_TIME %START_TIME% %TIME%
IF "%PS_CURRENT_STEP%" NEQ "arguments" (
    @ECHO.
    @ECHO Total Build Time Elapsed %ELAPSED_TIME%
)

:DIFF_TIME
@REM Calculates elapsed time between two timestamps (TIME environment variable format)
@REM %1 - Output variable
@REM %2 - Start time
@REM %3 - End time
setlocal EnableDelayedExpansion
set START_ARG=%2
set END_ARG=%3
set END=!END_ARG:%TIME:~8,1%=%%100)*100+1!
set START=!START_ARG:%TIME:~8,1%=%%100)*100+1!
set /A DIFF=((((10!END:%TIME:~2,1%=%%100)*60+1!%%100)-((((10!START:%TIME:~2,1%=%%100)*60+1!%%100), DIFF-=(DIFF^>^>31)*24*60*60*100
set /A CC=DIFF%%100+100,DIFF/=100,SS=DIFF%%60+100,DIFF/=60,MM=DIFF%%60+100,HH=DIFF/60+100
@endlocal & set %1=%HH:~1%%TIME:~2,1%%MM:~1%%TIME:~2,1%%SS:~1%%TIME:~8,1%%CC:~1%
@GOTO :EOF