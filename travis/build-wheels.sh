#!/bin/bash

/opt/_internal/cpython-3.5.1/bin/pip3.5 install --upgrade git+git://github.com/pypa/auditwheel

cd /io
git clone -q --branch=master https://github.com/Itseez/opencv.git opencv

for PYBIN in /opt/python/cp$PYTHON_VERSION*/bin; do
    $PYBIN/python find_version.py
    $PYBIN/pip install -r requirements.txt

    # Begin build
    cd opencv
    mkdir build
    if [[ $PYTHON_VERSION == 2* ]]; then
      cmake28 -H"." -B"build" -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python3=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
        -DPYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
        -DPYTHON2_EXECUTABLE=$PYBIN/python \
        -DPYTHON2_VERSION_STRING=$($PYBIN/python -c "from platform import python_version; print python_version()") \
        -DPYTHON2_INCLUDE_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -DPYTHON2_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -DPYTHON2_NUMPY_INCLUDE_DIRS=$($PYBIN/python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))") \
        -DPYTHON2_NUMPY_VERSION=$($PYBIN/python -c "import numpy; print(numpy.version.version)")
      (cd build; make -j5 opencv_python2)
    fi

    if [[ $PYTHON_VERSION == 3* ]]; then
      cmake28 -H"." -B"build" -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python2=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF \
        -DPYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
        -DPYTHON3_EXECUTABLE=$PYBIN/python \
        -DPYTHON3_VERSION_STRING=$($PYBIN/python -c "from platform import python_version; print python_version()") \
        -DPYTHON3_INCLUDE_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -DPYTHON3_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -DPYTHON3_NUMPY_INCLUDE_DIRS=$($PYBIN/python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))") \
        -DPYTHON3_NUMPY_VERSION=$($PYBIN/python -c "import numpy; print(numpy.version.version)")
      (cd build; make -j5 opencv_python3)
    fi
    cd ..

    if [[ $PYTHON_VERSION == 2* ]]; then
      cp opencv/build/lib/cv2.so cv2/
    fi

    if [[ $PYTHON_VERSION == 3* ]]; then
      cp opencv/build/lib/python3/*.so cv2/
    fi

    # Build wheel
    $PYBIN/pip wheel . -w tmpwheels/

    # Cleanup
    rm -fr opencv/build
    rm cv2/*.so
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
