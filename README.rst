.. image:: https://img.shields.io/appveyor/ci/skvark/opencv-python.svg?maxAge=3600&label=Windows
   :target: https://ci.appveyor.com/project/skvark/opencv-python
   :alt: AppVeyor CI test status (Windows)

.. image:: https://img.shields.io/travis/skvark/opencv-python.svg?maxAge=3600&label="Linux / OS X"
   :target: https://travis-ci.org/skvark/opencv-python
   :alt: Travis CI test status (Linux and OS X)

OpenCV on wheels
================

**Unofficial** OpenCV packages for Python.

Installation and Usage
----------------------

To install this package:

``pip install opencv-python``

To import the package:

``import cv2``

`OpenCV documentation <http://docs.opencv.org/>`__

IMPORTANT NOTE:

MacOS and Linux wheels have some limitations:

- video related functionality is not supported (not compiled with FFmpeg)
- for example ``cv.imshow()`` will not work (not compiled with GTK+ 2.x or Carbon support)

Documentation for opencv-python
-------------------------------

The aim of this repository is to provide means to package each new
`OpenCV release <https://github.com/opencv/opencv/releases>`__ for the
most used Python versions and platforms.

At the same time it allows anyone to build a custom version of OpenCV
for any Python version: just fork this repo and modify the build files
and scripts to fit your needs.

Build process
-------------

The project is structured like a normal Python package with a standard
``setup.py`` file. The build process is as follows (see for example
``appveyor.yml`` file):

1. Checkout repository and submodules

   -  OpenCV is included as submodule and the version is updated
      manually by maintainers when a new OpenCV release has been made

2. Find OpenCV version from the sources
3. Upgrade pip and install numpy for each Python version
4. Build OpenCV

   -  tests are disabled, otherwise build time increases too much

5. Copy each ``.pyd/.so`` file to cv2 folder of this project and
   generate wheel
6. Install the generated wheels for each Python version
7. Test that the Python versions can import them
8. Use twine to upload all wheels to PyPI

Currently the ``find_version.py`` file parses OpenCV version information
from the OpenCV sources. OpenCV depends on numpy, so ``setup.py`` checks
the numpy version also with the help of pip.

The ``cv2.pyd`` file for example on Windows is normally copied to site-packages.
To avoid polluting the root folder the ``__init__.py`` file in cv2 folder
handles the import logic correctly by importing the actual ``.pyd`` module
and replacing the imported cv2 package in ``sys.modudes`` with the
cv2 module to retain backward compatibility.

Licensing
---------

Opencv-python package (scripts in this repository) is available under
MIT license.

OpenCV itself is available under `3-clause BSD
License <https://github.com/opencv/opencv/blob/master/LICENSE>`__
(`LICENSE-3RD-PARTY.txt <https://github.com/skvark/opencv-python/blob/master/LICENSE-3RD-PARTY.txt>`__).

Windows wheels ship with `FFmpeg <http://ffmpeg.org>`__ licensed under the `LGPLv2.1 <http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>`__.

Versioning
----------

Currently the ``find_version.py`` script searches for the version
information from OpenCV sources and appends also a revision number
specific to this repository to the version string.

Releases
~~~~~~~~

A release is made and uploaded to PyPI when a new tag is pushed to
master branch. These tags differentiate packages (this repo might have
modifications but OpenCV version stays same) and should be incremented
sequentially. In practice, release version numbers look like this:

``cv_major.cv_minor.cv_revision.package_revision`` e.g. ``3.1.0.0``

Development builds
~~~~~~~~~~~~~~~~~~

Every commit to the master branch of this repo will be built. Possible
build artifacts use local version identifiers:

``cv_major.cv_minor.cv_revision+git_hash_of_this_repo`` e.g.
``3.1.0+14a8d39``

These artifacts can't be and will not be uploaded to PyPI.

Manylinux wheels
----------------

Linux wheels are built using
`manylinux <https://github.com/pypa/python-manylinux-demo>`__. These
wheels should work out of the box for most of the distros
(which use GNU C standard library) out there since they are built
against an old version of glibc.

Supported Python versions
-------------------------

Python 2.7 is the only supported version in 2.x series.
Python 3.x releases follow Numpy releases, for example
Python 3.3 is no longer supported by Numpy so the support
for it has been dropped in ``opencv-python`` too.

Currently, builds for following Python versions are provided:

- 2.7
- 3.4
- 3.5
- 3.6