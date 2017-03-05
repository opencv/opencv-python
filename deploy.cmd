cd %APPVEYOR_BUILD_FOLDER%

if %ENABLE_CONTRIB% EQU 1 (

	echo "This is contrib build. Deplyoment will be done to to PyPI entry opencv-contrib-python."
	if "%APPVEYOR_REPO_TAG%"=="true" ("%PYTHON%/python.exe" -m twine upload -u %USER% -p %PASS% --skip-existing dist/opencv*) else (echo "Tag not set, deployment skipped.")

) else (

	echo "This is default build. Deplyoment will be done to to PyPI entry opencv-python."
	if "%APPVEYOR_REPO_TAG%"=="true" ("%PYTHON%/python.exe" -m twine upload -u %USER% -p %PASS% --skip-existing dist/opencv*) else (echo "Tag not set, deployment skipped.")

)