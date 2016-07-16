| Platform| Status |
| :---: | :---: |
| Windows | [![buildstatus](https://ci.appveyor.com/api/projects/status/5kjqpmvll5dwj5jd?svg=true)](https://ci.appveyor.com/project/skvark/opencv-python) |
| Manylinux|  [![Build Status](https://travis-ci.org/skvark/opencv-python.svg?branch=master)](https://travis-ci.org/skvark/opencv-python) |

# OpenCV on wheels

Work in progress!

The aim of this repository is to provide means to package each new [OpenCV release](https://github.com/Itseez/opencv/releases) for the most used Python versions and platforms.

At the same time it allows anyone to build a custom version of OpenCV for any Python version: just fork this repo and modify the build files and scripts to fit your needs.

## Why?

1. Installation of OpenCV for Python is pretty hideous:
	1. Download OpenCV
	2. Find cv2.pyd from the package
		- If it exists, copy it to the root of Python site-packages
		- If it does not exist for some reason for your setup, you have to setup the build environment and compile it manually
	3. Try to import cv2 and hope it works
2. Everyone should be able to install OpenCV (or any package for that matter) with pip with a single command without building anything
3. Python [wheels](http://pythonwheels.com/) are nice, we should use them more

## Documentation

The project is structured like a normal Python package with a standard ``setup.py`` file. The build process is as follows (see ``appveyor.yml``):

1. Checkout OpenCV (TO DO: pull only latest tag)
2. Find OpenCV version from the sources
2. Upgrade pip and install numpy for each Python version
3. Build OpenCV
	- tests are disabled, otherwise build time increases too much
4. Copy each ``.pyd/.so`` file to cv2 folder of this project and generate wheel
5. Install the generated wheels for each Python version
6. Test that the Python versions can import them
7. TO DO: upload the wheels to PyPi

Currently the ``setup.py`` file parses OpenCV version information from the OpenCV sources. OpenCV depends on numpy, so ``setup.py`` checks the numpy version also with the help of pip.

As described earlier, for example the ``.pyd`` file on Windows is normally copied to site-packages. I don't want to pollute the root folder, so the ``__init__.py`` file in cv2 folder handles the import logic correctly by importing the actual ``.pyd`` module and replacing the imported cv2 package in ``sys.modudes`` with the cv2 module to retain backward compatibility.

## Manylinux wheels

Linux wheels are built using [manylinux](https://github.com/pypa/python-manylinux-demo). These wheels should work out of the box for most of the distros out there since they are built against an old version of glibc.

## Versioning

Currently the ``find_version.py`` script searches for the version information from OpenCV sources. The CI build number is then added after the actual OpenCV version to differentiate packages (this repo might have modifications but OpenCV version stays same).

## Supported Python versions

#### Windows: 

There's a build time limitation (AppVeyor open source builds may take max. 1 hour) which restricts the supported Python versions to two. As Python's 2.x releases are slowly approaching legacy state, 2.7.x releases will be the only supported Python 2 versions on Windows. On Python 3 side, builds will be run only for the latest release.

However, if you wan't to get some other versions, just fork this repo and change the dependencies.

#### Linux

Manylinux wheels are built for all the Python versions which are supported by the manylinux containers.

#### OS X

TODO


