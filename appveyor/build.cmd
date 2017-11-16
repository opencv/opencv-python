if not exist "%APPVEYOR_BUILD_FOLDER%\opencv\%BUILD_DIR%" mkdir "%APPVEYOR_BUILD_FOLDER%\opencv\%BUILD_DIR%"

cd opencv

if not "%BUILD_TOOLSET%" == "" set ARG_TOOLSET=-T %BUILD_TOOLSET%
if %ENABLE_CONTRIB% EQU 1 (

  if %PYTHON_VERSION% GEQ 3 cmake -G "%BUILD_ENV%" %ARG_TOOLSET% -H"." -B"%BUILD_DIR%" -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DPYTHON3_EXECUTABLE="%PYTHON%/python.exe" -DPYTHON3_LIBRARY="%PYTHON%/libs/python3*.lib" -DPYTHON3_INCLUDE_DIR="%PYTHON%/include" -Wno-dev || exit /b 1
  if %PYTHON_VERSION% LSS 3 cmake -G "%BUILD_ENV%" %ARG_TOOLSET% -H"." -B"%BUILD_DIR%" -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -Wno-dev || exit /b 1

) else (

  if %PYTHON_VERSION% GEQ 3 cmake -G "%BUILD_ENV%" %ARG_TOOLSET% -H"." -B"%BUILD_DIR%" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DPYTHON3_EXECUTABLE="%PYTHON%/python.exe" -DPYTHON3_LIBRARY="%PYTHON%/libs/python3*.lib" -DPYTHON3_INCLUDE_DIR="%PYTHON%/include" -Wno-dev || exit /b 1
  if %PYTHON_VERSION% LSS 3 cmake -G "%BUILD_ENV%" %ARG_TOOLSET% -H"." -B"%BUILD_DIR%" -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -Wno-dev || exit /b 1

)

cd %BUILD_DIR% || exit /b 1

cmake --build . --config Release || exit /b 1

cd ..\.. || exit /b 1
cd

if %PYTHON_VERSION% GEQ 3 xcopy "%APPVEYOR_BUILD_FOLDER%\opencv\%BUILD_DIR%\lib\python3\Release\*.pyd" .\cv2 /I || exit /b 1
if %PYTHON_VERSION% LSS 3 xcopy "%APPVEYOR_BUILD_FOLDER%\opencv\%BUILD_DIR%\lib\RELEASE\*.pyd" .\cv2 /I || exit /b 1

xcopy "%APPVEYOR_BUILD_FOLDER%\opencv\%BUILD_DIR%\bin\Release\*.dll" .\cv2 /I
xcopy "%APPVEYOR_BUILD_FOLDER%\LICENSE*.txt" .\cv2 /I || exit /b 1

dir

"%PYTHON%/python.exe" setup.py bdist_wheel || exit /b 1
