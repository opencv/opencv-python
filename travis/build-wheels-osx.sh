#!/bin/bash
set +e
echo 'Begin build-wheel OSX ...'

export PYTHON_VERSION=${MB_PYTHON_VERSION/./}
echo 'MB_PYTHON_VERSION: ' "$MB_PYTHON_VERSION"
echo 'PYTHON_VERSION: ' "$PYTHON_VERSION"

echo 'PIP and brew installs'

pip install "$BUILD_DEPENDS"

echo 'Installing QT4'
brew tap cartr/qt4
brew tap-pin cartr/qt4
brew install qt@4
echo '-----------------'
echo 'Installing FFmpeg'
brew install ffmpeg --without-x264 --without-xvid --without-gpl
brew info ffmpeg
echo '-----------------'

qmake -query

cd opencv

echo "Apply patch"

git apply --ignore-space-change --ignore-whitespace ../travis/disable_i386.patch

echo "Detect Python paths for OpenCV"

PYTHON_VERSION_STRING=$(python -c "from platform import python_version; print(python_version())")
PYTHON_INCLUDE_PATH=$(python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())")
PYTHON_PACKAGES_PATH=$(python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
PYTHON_NUMPY_INCLUDE_DIRS=$(python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))")
PYTHON_NUMPY_VERSION=$(python -c "import numpy; print(numpy.version.version)")

echo "PYthon version string: $PYTHON_VERSION_STRING"
echo "Python include path: $PYTHON_INCLUDE_PATH"
echo "Python packages path: $PYTHON_PACKAGES_PATH"
echo "Python numpy incude dirs: $PYTHON_NUMPY_INCLUDE_DIRS"
echo "Python numpy version: $PYTHON_NUMPY_VERSION"

echo 'Config make'

mkdir build
cd build

if [[ $PYTHON_VERSION == 2* ]] && [[ $ENABLE_CONTRIB == 0 ]]; then
  echo 'Config for Py2'
  cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D CMAKE_TOOLCHAIN_FILE=../../travis/toolchain_macos.cmake \
    -D BUILD_opencv_python3=OFF -D BUILD_opencv_java=OFF -D BUILD_SHARED_LIBS=OFF -D WITH_LAPACK=OFF -D WITH_QT=4 \
    -D INSTALL_C_EXAMPLES=OFF -D INSTALL_PYTHON_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D PYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
    -D PYTHON2_EXECUTABLE=python \
    -D PYTHON2_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -D PYTHON2_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -D PYTHON2_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -D PYTHON2_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -D PYTHON2_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    ..

fi

if [[ $PYTHON_VERSION == 3* ]] && [[ $ENABLE_CONTRIB == 0 ]]; then
  echo 'Config for Py3'
  cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D CMAKE_TOOLCHAIN_FILE=../../travis/toolchain_macos.cmake \
    -D BUILD_opencv_python2=OFF -D BUILD_opencv_java=OFF -D BUILD_SHARED_LIBS=OFF -D WITH_LAPACK=OFF -D WITH_QT=4 \
    -D INSTALL_C_EXAMPLES=OFF -D INSTALL_PYTHON_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D PYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
    -D PYTHON3_EXECUTABLE=python \
    -D PYTHON3_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -D PYTHON3_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -D PYTHON3_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -D PYTHON3_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -D PYTHON3_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    ..

fi

if [[ $PYTHON_VERSION == 2* ]] && [[ $ENABLE_CONTRIB == 1 ]]; then
  echo 'Config for Py2'
  cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D CMAKE_TOOLCHAIN_FILE=../../travis/toolchain_macos.cmake -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
    -D BUILD_opencv_python3=OFF -D BUILD_opencv_java=OFF -D BUILD_SHARED_LIBS=OFF -D WITH_LAPACK=OFF -D WITH_QT=4 \
    -D INSTALL_C_EXAMPLES=OFF -D INSTALL_PYTHON_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D PYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
    -D PYTHON2_EXECUTABLE=python \
    -D PYTHON2_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -D PYTHON2_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -D PYTHON2_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -D PYTHON2_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -D PYTHON2_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    ..

fi

if [[ $PYTHON_VERSION == 3* ]] && [[ $ENABLE_CONTRIB == 1 ]]; then
  echo 'Config for Py3'
  cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D CMAKE_TOOLCHAIN_FILE=../../travis/toolchain_macos.cmake -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
    -D BUILD_opencv_python2=OFF -D BUILD_opencv_java=OFF -D BUILD_SHARED_LIBS=OFF -D WITH_LAPACK=OFF -D WITH_QT=4 \
    -D INSTALL_C_EXAMPLES=OFF -D INSTALL_PYTHON_EXAMPLES=OFF -D BUILD_TESTS=OFF -D BUILD_PERF_TESTS=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D PYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
    -D PYTHON3_EXECUTABLE=python \
    -D PYTHON3_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -D PYTHON3_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -D PYTHON3_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -D PYTHON3_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -D PYTHON3_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    ..

fi

echo 'Begin build'

if [[ $PYTHON_VERSION == 2* ]]; then
  echo 'Build for Py2'
  make -j2 opencv_python2

fi

if [[ $PYTHON_VERSION == 3* ]]; then
  echo 'Build for Py3'
  make -j2 opencv_python3

fi

# Moving back to opencv-python
cd ../..

if [[ $PYTHON_VERSION == 2* ]]; then
  echo 'Copying *.so for Py2'
  cp opencv/build/lib/cv2.so cv2/

fi

if [[ $PYTHON_VERSION == 3* ]]; then
  echo 'Copying *.so for Py3'
  cp opencv/build/lib/python3/*.so cv2/

fi

echo 'Build wheel'

