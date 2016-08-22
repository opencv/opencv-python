#!/bin/bash

PYTHON=python$PYTHON_VERSION

echo "Starting tests..."

#Test package
$PYTHON -m unittest test
