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

echo cmake ../ -G "Visual Studio 16 2019" -A x64 -DDESTDIR="%CD%/PantheonSlicer_dep" -DCMAKE_BUILD_TYPE=%build_type% -DDEP_DEBUG=%debug% -DORCA_INCLUDE_DEBUG_INFO=%debuginfo%
cmake ../ -G "Visual Studio 16 2019" -A x64 -DDESTDIR="%CD%/PantheonSlicer_dep" -DCMAKE_BUILD_TYPE=%build_type% -DDEP_DEBUG=%debug% -DORCA_INCLUDE_DEBUG_INFO=%debuginfo%
cmake --build . --config %build_type% --target deps -- -m

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
:: %1 = output variable name
:: %2 = start time
:: %3 = end time
setlocal

set "ts=%~2"
set "te=%~3"

:: Normalize to HH:MM:SS.CC
for /f "tokens=1-4 delims=.:," %%a in ("%ts%") do (
    set /a sh=1%%a%%100, sm=1%%b%%100, ss=1%%c%%100, sc=1%%d%%100
)
for /f "tokens=1-4 delims=.:," %%a in ("%te%") do (
    set /a eh=1%%a%%100, em=1%%b%%100, es=1%%c%%100, ec=1%%d%%100
)

:: Convert to centiseconds
set /a startTotal=((sh*60+sm)*60+ss)*100+sc
set /a endTotal=((eh*60+em)*60+es)*100+ec

:: If rollover (past midnight)
if %endTotal% LSS %startTotal% set /a endTotal+=24*60*60*100

set /a diff=endTotal-startTotal

:: Extract HH:MM:SS.CC
set /a cc=diff%%100, diff/=100
set /a ss=diff%%60, diff/=60
set /a mm=diff%%60, diff/=60
set /a hh=diff

:: Return value
endlocal & set "%1=%hh%:%mm%:%ss%.%cc%"
goto :EOF
