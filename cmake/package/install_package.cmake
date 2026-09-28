# Runs at install time, after the rest of OpenCV is installed.
# The prefix can be relative (scikit-build-core passes a relative --prefix)
get_filename_component(_prefix "${CMAKE_INSTALL_PREFIX}" ABSOLUTE)
set(_loader "${_prefix}/${OPENCV_PYTHON_LOADER_PATH}")
set(_cv2 "${_prefix}/cv2")

# Copy files matching GLOB (flattened) into cv2/<dest>. A macro, since
# file(INSTALL) records files in CMAKE_INSTALL_MANIFEST_FILES in the current scope.
macro(opencv_python_install dest)
  cmake_parse_arguments(ARG "OPTIONAL;RECURSE" "GLOB" "" ${ARGN})
  if(ARG_RECURSE)
    file(GLOB_RECURSE _files LIST_DIRECTORIES false "${ARG_GLOB}")
  else()
    file(GLOB _files LIST_DIRECTORIES false "${ARG_GLOB}")
  endif()
  if(NOT _files)
    if(NOT ARG_OPTIONAL)
      message(FATAL_ERROR "Not found: ${ARG_GLOB}")
    endif()
  else()
    string(REGEX REPLACE "/$" "" _dest "${_cv2}/${dest}")
    file(INSTALL ${_files} DESTINATION "${_dest}")
  endif()
endmacro()

opencv_python_install("" GLOB "${_loader}/python-3*/cv2*")
opencv_python_install("" GLOB "${_loader}/__init__.py")
opencv_python_install("" GLOB "${_loader}/py.typed")

# The versioned config points at the python-3* directory; replace it with our
# loader config for the flat layout.
file(GLOB _configs LIST_DIRECTORIES false "${_loader}/*config*.py")
if(NOT _configs)
  message(FATAL_ERROR "Not found: ${_loader}/*config*.py")
endif()
foreach(_config IN LISTS _configs)
  get_filename_component(_name "${_config}" NAME)
  if(_name MATCHES "^config-3")
    file(INSTALL "${OPENCV_PYTHON_ROOT}/scripts/__init__.py" DESTINATION "${_cv2}" RENAME "${_name}")
  else()
    file(INSTALL "${_config}" DESTINATION "${_cv2}")
  endif()
endforeach()

file(GLOB_RECURSE _stubs LIST_DIRECTORIES false RELATIVE "${_loader}" "${_loader}/*.pyi")
foreach(_stub IN LISTS _stubs)
  get_filename_component(_dir "${_stub}" DIRECTORY)
  string(REGEX REPLACE "/$" "" _dest "${_cv2}/${_dir}")
  file(INSTALL "${_loader}/${_stub}" DESTINATION "${_dest}")
endforeach()

# gapi can be missing if ADE was not downloaded (network issue)
opencv_python_install(gapi OPTIONAL RECURSE GLOB "${_loader}/gapi/*.py")
foreach(_subpackage mat_wrapper misc utils typing)
  opencv_python_install(${_subpackage} RECURSE GLOB "${_loader}/${_subpackage}/*.py")
endforeach()

opencv_python_install(data GLOB "${_prefix}/${OPENCV_PYTHON_OTHER_PATH}/haarcascades/*.xml")

if(OPENCV_PYTHON_WIN32)
  opencv_python_install("" GLOB "${_prefix}/${OPENCV_PYTHON_BIN_PATH}/opencv_videoio_ffmpeg*.dll")
endif()

# Only present for Linux CI builds with Qt (patches/patchQtPlugins)
opencv_python_install(qt/plugins/platforms OPTIONAL GLOB "${_prefix}/lib/qt/plugins/platforms/libqxcb.so")
opencv_python_install(qt/fonts OPTIONAL GLOB "${_prefix}/lib/qt/fonts/dejavu/*.ttf")

file(INSTALL "${OPENCV_PYTHON_ROOT}/LICENSE.txt" "${OPENCV_PYTHON_ROOT}/LICENSE-3RD-PARTY.txt" DESTINATION "${_cv2}")
