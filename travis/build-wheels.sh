#!/bin/bash
set +e
echo 'Begin build-wheel...'

export PYTHON_VERSION=${PYTHON_VERSION/./}

echo 'PYTHON_VERSION: '$PYTHON_VERSION

ENABLE_CONTRIB=$(<contrib.enabled)

for PYBIN in /opt/python/cp$PYTHON_VERSION*/bin; do
    echo 'PWD  : '$PWD
    echo 'PYBIN: '$PYBIN

    $PYBIN/pip install -r requirements.txt

    # Begin build
    echo 'Begin build'
    cd opencv
    mkdir build
    if [[ $PYTHON_VERSION == 2* ]] && [[ $ENABLE_CONTRIB == 0 ]]; then
      echo 'Config for Py2'
      cmake28 -H"." -B"build" -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python3=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DWITH_IPP=OFF -DBUILD_DOCS=OFF \
        -DPYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
        -DPYTHON2_EXECUTABLE=$PYBIN/python \
        -DPYTHON2_VERSION_STRING=$($PYBIN/python -c "from platform import python_version; print python_version()") \
        -DPYTHON2_INCLUDE_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -DPYTHON2_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -DPYTHON2_NUMPY_INCLUDE_DIRS=$($PYBIN/python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))") \
        -DPYTHON2_NUMPY_VERSION=$($PYBIN/python -c "import numpy; print(numpy.version.version)")
    fi

    if [[ $PYTHON_VERSION == 3* ]] && [[ $ENABLE_CONTRIB == 0 ]]; then
      echo 'Config for Py3'
      cmake28 -H"." -B"build" -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python2=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DWITH_IPP=OFF -DBUILD_DOCS=OFF \
        -DPYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
        -DPYTHON3_EXECUTABLE=$PYBIN/python \
        -DPYTHON3_VERSION_STRING=$($PYBIN/python -c "from platform import python_version; print python_version()") \
        -DPYTHON3_INCLUDE_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -DPYTHON3_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -DPYTHON3_NUMPY_INCLUDE_DIRS=$($PYBIN/python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))") \
        -DPYTHON3_NUMPY_VERSION=$($PYBIN/python -c "import numpy; print(numpy.version.version)")
    fi

    if [[ $PYTHON_VERSION == 2* ]] && [[ $ENABLE_CONTRIB == 1 ]]; then
      echo 'Config for Py2'
      cmake28 -H"." -B"build" -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python3=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DWITH_IPP=OFF -DBUILD_DOCS=OFF \
        -DPYTHON2INTERP_FOUND=ON -DPYTHON2LIBS_FOUND=ON \
        -DPYTHON2_EXECUTABLE=$PYBIN/python \
        -DPYTHON2_VERSION_STRING=$($PYBIN/python -c "from platform import python_version; print python_version()") \
        -DPYTHON2_INCLUDE_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -DPYTHON2_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -DPYTHON2_NUMPY_INCLUDE_DIRS=$($PYBIN/python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))") \
        -DPYTHON2_NUMPY_VERSION=$($PYBIN/python -c "import numpy; print(numpy.version.version)")
    fi

    if [[ $PYTHON_VERSION == 3* ]] && [[ $ENABLE_CONTRIB == 1 ]]; then
      echo 'Config for Py3'
      cmake28 -H"." -B"build" -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules -DCMAKE_BUILD_TYPE=Release -DBUILD_opencv_python2=OFF -DBUILD_opencv_java=OFF -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DWITH_IPP=OFF -DBUILD_DOCS=OFF \
        -DPYTHON3INTERP_FOUND=ON -DPYTHON3LIBS_FOUND=ON \
        -DPYTHON3_EXECUTABLE=$PYBIN/python \
        -DPYTHON3_VERSION_STRING=$($PYBIN/python -c "from platform import python_version; print python_version()") \
        -DPYTHON3_INCLUDE_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
        -DPYTHON3_PACKAGES_PATH=$($PYBIN/python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        -DPYTHON3_NUMPY_INCLUDE_DIRS=$($PYBIN/python -c "import os; os.environ['DISTUTILS_USE_SDK']='1'; import numpy.distutils; print(os.pathsep.join(numpy.distutils.misc_util.get_numpy_include_dirs()))") \
        -DPYTHON3_NUMPY_VERSION=$($PYBIN/python -c "import numpy; print(numpy.version.version)")
    fi

    if [[ $PYTHON_VERSION == 2* ]]; then
      echo 'Build for Py2'
      (cd build; make -j2 opencv_python2)
    fi

    if [[ $PYTHON_VERSION == 3* ]]; then
      echo 'Build for Py3'
      (cd build; make -j2 opencv_python3)
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
    $PYBIN/pip wheel . -w /io/wheelhouse/

    # Cleanup
    echo 'Cleanup'
    rm -fr opencv/build
    rm cv2/*.so
done
