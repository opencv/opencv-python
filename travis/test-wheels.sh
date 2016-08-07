#!/bin/bash

PYTHON=python$PYTHON_VERSION
echo "Starting tests..."
apt-get -y install libglib2.0-0

cd /io/tests/

#Test package
$PYTHON -m unittest test
