#!/bin/bash

/opt/_internal/cpython-3.5.1/bin/pip3.5 install --upgrade git+git://github.com/pypa/auditwheel

cd /io
git clone -q --branch=python-wheel https://github.com/c-martinez/opencv.git opencv

for PYBIN in /opt/python/cp$PYTHON_VERSION*/bin; do
    $PYBIN/python find_version.py
    $PYBIN/pip install -r requirements.txt

    # Begin build
    cd opencv
    mkdir build
    if [[ $PYTHON_VERSION == 2* ]]; then
      cmake28 -H"." -B"build" -DCMAKE_BUILD_TYPE=RELEASE -DBUILD_opencv_python3=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF  -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DPYTHON_EXECUTABLE=$PYBIN/python -DPYTHON_INCLUDE_DIR=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") -DPYTHON_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") -Wno-dev;
    fi

    if [[ $PYTHON_VERSION == 3* ]]; then
      cmake28 -H"." -B"build" -DCMAKE_BUILD_TYPE=RELEASE -DBUILD_opencv_python2=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF  -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DPYTHON3_EXECUTABLE=$PYBIN/python -DPYTHON_INCLUDE_DIR=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") -DPYTHON_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") -Wno-dev;
    fi

    # DO BUILD
    cd build
    cmake28 --build . --config Release
    cd ../..

    if [[ $PYTHON_VERSION == 2* ]]; then
      cp opencv/build/lib/cv2.so cv2/
    fi

    if [[ $PYTHON_VERSION == 3* ]]; then
      cp opencv/build/lib/python3/*.so cv2/
    fi
    rm -fr opencv/build

    # Build wheel
    $PYBIN/pip wheel . -w tmpwheels/
done

# Bundle external shared libraries into the wheels
for whl in tmpwheels/opencv*.whl; do
    auditwheel repair $whl -w /io/wheelhouse/
done
rm -fr tmpwheels/

cd tests
# Install packages and test
for PYBIN in /opt/python/cp$PYTHON_VERSION*/bin/; do
    $PYBIN/pip install opencv-python --no-index -f /io/wheelhouse
    $PYBIN/python -m unittest test
done
