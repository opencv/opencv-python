#!/bin/bash
set +e
echo 'Begin build-wheel...'

export PYTHON_VERSION=${PYTHON_VERSION/./}
echo 'PYTHON_VERSION: ' "$PYTHON_VERSION"

ENABLE_CONTRIB=$(<contrib.enabled)

pip install "$BUILD_DEPENDS"

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

# Begin build
echo 'Begin build'
cd opencv

mkdir build

ffmpeg -L
qmake -query

if [[ $PYTHON_VERSION == 2* ]] && [[ $ENABLE_CONTRIB == 0 ]]; then
  echo 'Config for Py2'
  cmake -H"." -B"build" -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python3=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
    -DWITH_IPP=OFF -DBUILD_DOCS=OFF -DWITH_QT=4 \
    -DINSTALL_C_EXAMPLES=OFF -DINSTALL_PYTHON_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DPYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
    -DPYTHON2_EXECUTABLE=python \
    -DPYTHON2_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -DPYTHON2_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -DPYTHON2_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -DPYTHON2_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -DPYTHON2_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    -DWITH_JPEG=ON \
    -DBUILD_JPEG=OFF \
    -DJPEG_INCLUDE_DIR="$JPEG_INCLUDE_DIR" \
    -DJPEG_LIBRARY="$JPEG_LIBRARY" \
    -DWITH_V4L=ON

fi

if [[ $PYTHON_VERSION == 3* ]] && [[ $ENABLE_CONTRIB == 0 ]]; then
  echo 'Config for Py3'
  cmake -H"." -B"build" -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python2=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
    -DWITH_IPP=OFF -DBUILD_DOCS=OFF -DWITH_QT=4 \
    -DINSTALL_C_EXAMPLES=OFF -DINSTALL_PYTHON_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DPYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
    -DPYTHON3_EXECUTABLE=python \
    -DPYTHON3_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -DPYTHON3_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -DPYTHON3_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -DPYTHON3_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -DPYTHON3_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    -DWITH_JPEG=ON \
    -DBUILD_JPEG=OFF \
    -DJPEG_INCLUDE_DIR="$JPEG_INCLUDE_DIR" \
    -DJPEG_LIBRARY="$JPEG_LIBRARY" \
    -DWITH_V4L=ON

fi

if [[ $PYTHON_VERSION == 2* ]] && [[ $ENABLE_CONTRIB == 1 ]]; then
  echo 'Config for Py2'
  cmake -H"." -B"build" -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python3=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
    -DWITH_IPP=OFF -DBUILD_DOCS=OFF -DWITH_QT=4 \
    -DINSTALL_C_EXAMPLES=OFF -DINSTALL_PYTHON_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DPYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
    -DPYTHON2_EXECUTABLE=python \
    -DPYTHON2_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -DPYTHON2_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -DPYTHON2_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -DPYTHON2_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -DPYTHON2_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    -DWITH_JPEG=ON \
    -DBUILD_JPEG=OFF \
    -DJPEG_INCLUDE_DIR="$JPEG_INCLUDE_DIR" \
    -DJPEG_LIBRARY="$JPEG_LIBRARY" \
     -DWITH_V4L=ON

fi

if [[ $PYTHON_VERSION == 3* ]] && [[ $ENABLE_CONTRIB == 1 ]]; then
  echo 'Config for Py3'
  cmake -H"." -B"build" -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python2=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
    -DWITH_IPP=OFF -DBUILD_DOCS=OFF -DWITH_QT=4 \
    -DINSTALL_C_EXAMPLES=OFF -DINSTALL_PYTHON_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DPYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
    -DPYTHON3_EXECUTABLE=python \
    -DPYTHON3_VERSION_STRING="$PYTHON_VERSION_STRING" \
    -DPYTHON3_INCLUDE_PATH="$PYTHON_INCLUDE_PATH" \
    -DPYTHON3_PACKAGES_PATH="$PYTHON_PACKAGES_PATH" \
    -DPYTHON3_NUMPY_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE_DIRS" \
    -DPYTHON3_NUMPY_VERSION="$PYTHON_NUMPY_VERSION" \
    -DWITH_JPEG=ON \
    -DBUILD_JPEG=OFF \
    -DJPEG_INCLUDE_DIR="$JPEG_INCLUDE_DIR" \
    -DJPEG_LIBRARY="$JPEG_LIBRARY" \
    -DWITH_V4L=ON

fi

if [[ $PYTHON_VERSION == 2* ]]; then
  echo 'Build for Py2'
  (cd build; make -j8 opencv_python2)

fi

if [[ $PYTHON_VERSION == 3* ]]; then
  echo 'Build for Py3'
  (cd build; make -j8 opencv_python3)

fi

# Moving back to opencv-python
cd ..

if [[ $PYTHON_VERSION == 2* ]]; then
  echo 'Copying *.so for Py2'
  cp opencv/build/lib/cv2.so cv2/

fi

if [[ $PYTHON_VERSION == 3* ]]; then
  echo 'Copying *.so for Py3'
  cp opencv/build/lib/python3/*.so cv2/

fi

# Build wheel
echo 'Build wheel'
pip wheel . -w /io/wheelhouse/