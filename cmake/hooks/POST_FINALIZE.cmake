# OpenCV hook (see OPENCV_CMAKE_HOOKS_DIR), included at the end of the root CMakeLists.txt.
# A subdirectory added last installs after all of OpenCV, for any CMP0082 setting.
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../package" "${CMAKE_BINARY_DIR}/opencv-python-package")
