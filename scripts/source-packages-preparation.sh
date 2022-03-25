#!/bin/bash

# ${1} variable is a path to repository opencv-python

# Define flags
if [ "0" == $ENABLE_CONTRIB ]; then
  git submodule update --init opencv
  EXTRA_CMAKE_OPTIONS="-DOPENCV_DOWNLOAD_PATH=${1}/opencv/3rdparty"
else
  git submodule update --init opencv opencv_contrib
  EXTRA_CMAKE_OPTIONS="-DOPENCV_DOWNLOAD_PATH=${1}/opencv/3rdparty -DOPENCV_EXTRA_MODULES_PATH=${1}/opencv_contrib/modules"
fi

# Download 3rdparty files
cd opencv && \
mkdir generate && \
cd generate && \
cmake $EXTRA_CMAKE_OPTIONS ${1}/opencv && \
cd ${1} && \
rm -rf opencv/generate
