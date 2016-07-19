#!/bin/bash

set +e
echo 'Begin build-wheel OSX ...'

echo 'PIP and brew installs'

pip install numpy
brew install cmake pkg-config
brew install jpeg libpng libtiff openexr
brew install eigen tbb

echo 'Begin our build'
ls -lh

python ./find_version.py
pip install -r requirements.txt

echo 'Config make'

cd opencv
mkdir build
cd build

cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local \
  -D BUILD_opencv_python3=OFF -D BUILD_opencv_java=OFF -D BUILD_SHARED_LIBS=OFF \
  -D PYTHON2_PACKAGES_PATH=$(python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
	-D PYTHON2_LIBRARY=/usr/local/Cellar/python/2.7.10/Frameworks/Python.framework/Versions/2.7/bin \
	-D PYTHON2_INCLUDE_DIR=/Library/Frameworks/Python.framework/Versions/2.7/include/python2.7 \
	-D INSTALL_C_EXAMPLES=OFF -D INSTALL_PYTHON_EXAMPLES=OFF \
	-D BUILD_EXAMPLES=OFF ..

echo 'Begin build'
make -j4

# Moving back to opencv-python
cd ../..

echo 'Copying *.so for Py2'
cp opencv/build/lib/cv2.so cv2/

echo 'Build wheel'
# pip wheel . -w ./wheelhouse/

echo 'Cleanup'
# rm -fr opencv/build
# rm cv2/*.so
