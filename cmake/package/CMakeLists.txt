# Arrange the installed OpenCV Python files into the cv2 package, under
# <prefix>/cv2. setup.py only keeps the files in there.
get_filename_component(OPENCV_PYTHON_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

install(CODE "
set(OPENCV_PYTHON_ROOT \"${OPENCV_PYTHON_ROOT}\")
set(OPENCV_PYTHON_LOADER_PATH \"${OPENCV_PYTHON3_INSTALL_PATH}/cv2\")
set(OPENCV_PYTHON_OTHER_PATH \"${OPENCV_OTHER_INSTALL_PATH}\")
set(OPENCV_PYTHON_BIN_PATH \"${OPENCV_BIN_INSTALL_PATH}\")
set(OPENCV_PYTHON_WIN32 \"${WIN32}\")
")
install(SCRIPT "${CMAKE_CURRENT_LIST_DIR}/install_package.cmake")
