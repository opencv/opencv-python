#!/bin/bash
pip install numpy
brew install cmake pkg-config
brew install jpeg libpng libtiff openexr
brew install eigen tbb

cd opencv
mkdir build
cd build
