OpenCV on Wheels
================

**Unofficial** OpenCV packages for Python.

This package contains only the OpenCV core modules without the optional contrib modules.
If you are looking for a version which includes OpenCV contrib modules, please install `opencv-contrib-python <https://pypi.python.org/pypi/opencv-contrib-python>`__ instead.

The packages contain pre-compiled OpenCV binary with Python bindings.
This enables super fast (usually < 10 seconds) OpenCV installation for Python.

If you need only OpenCV Python bindings, no separate OpenCV installation is required.

Installation and Usage
----------------------

1. If you have previous/other version of OpenCV installed (e.g. cv2 module in the root of Python's site-packages), remove it before installation to avoid conflicts.

 - To further avoid conflicts and to make development easier, Python's `virtual environments <https://docs.python.org/3/library/venv.html>`__ are highly recommended for development purposes.

2. If you have an existing ``opencv-contrib-python`` installation, run ``pip uninstall opencv-contrib-python``

3. Install this package:

``pip install opencv-python``

4. Import the package:

``import cv2``

The package contains haarcascade files. ``cv2.data.haarcascades`` can be used as a shortcut to the data folder. For example:

``cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml")``

5. Read `OpenCV documentation <http://docs.opencv.org/>`__

6. Before opening a new issue, read the FAQ below and have a look at the other issues which are already open.

Frequently Asked Questions
--------------------------

**Q: Do I need to install also OpenCV separately?**

A: No, the packages are special wheel binary packages and they already contain statically built OpenCV binaries.

**Q: Pip does not find package ``opencv-python``?**

A: The wheel package format and manylinux builds are pretty new things. Most likely the issue is related to too old pip and can be fixed by running ``pip install --upgrade pip`` and ``pip install wheel``.

**Q: I need contrib modules?**

A: Please install `opencv-contrib-python <https://pypi.python.org/pypi/opencv-contrib-python>`__ instead. However, note that commercial usage might be restricted in some countries since the contrib modules might contain some non-free/patented algorithms.

**Q: Import fails on Windows to some DLL load error?**

A: If the import fails on Windows, make sure you have `Visual C++ redistributable 2015 <https://www.microsoft.com/en-us/download/details.aspx?id=48145>`__ installed. If you are using older Windows version than Windows 10 and latest system updates are not installed, `Universal C Runtime <https://support.microsoft.com/en-us/help/2999226/update-for-universal-c-runtime-in-windows>`__ might be also required.

See also `this issue <https://github.com/skvark/opencv-python/issues/36>`__ if you are using Anaconda.

**Q: I have some other import errors?**

A: Make sure you have removed old manual installations of OpenCV Python bindings (cv2.so or cv2.pyd in site-packages).

Documentation for opencv-python
-------------------------------

.. image:: https://img.shields.io/appveyor/ci/skvark/opencv-python.svg?maxAge=3600&label=Windows
   :target: https://ci.appveyor.com/project/skvark/opencv-python
   :alt: AppVeyor CI test status (Windows)

.. image:: https://img.shields.io/travis/skvark/opencv-python.svg?maxAge=3600&label="Linux / OS X"
   :target: https://travis-ci.org/skvark/opencv-python
   :alt: Travis CI test status (Linux and OS X)

The aim of this repository is to provide means to package each new
`OpenCV release <https://github.com/opencv/opencv/releases>`__ for the
most used Python versions and platforms.

At the same time it allows anyone to build a custom version of OpenCV
for any Python version: just fork this repo and modify the build files
and scripts to fit your needs.

Build process
-------------

The project is structured like a normal Python package with a standard
``setup.py`` file. The build process for a single entry in the build matrices is as follows (see for example
``appveyor.yml`` file):

1. Checkout repository and submodules

   -  OpenCV is included as submodule and the version is updated
      manually by maintainers when a new OpenCV release has been made
   -  Contrib modules are also included as a submodule

2. Find OpenCV version from the sources
3. Install dependencies (numpy)
4. Build OpenCV

   -  tests are disabled, otherwise build time increases too much
   -  there are 2 build matrix entries for each build combination: with and without contrib modules
   -  Linux builds run in manylinux Docker containers (CentOS 5)

5. Copy each ``.pyd/.so`` file to cv2 folder of this project and
   generate wheel

   - Linux and macOS wheels are checked with auditwheel and delocate

6. Install the generated wheel
7. Test that Python can import the library and run some sanity checks
8. Use twine to upload the generated wheel to PyPI (only in release builds)

Currently the ``find_version.py`` file parses OpenCV version information
from the OpenCV sources. OpenCV depends on numpy, so ``setup.py`` checks
the minimum required numpy version also with the help of pip.

The ``cv2.pyd/.so`` file is normally copied to site-packages.
To avoid polluting the root folder this package wraps
the statically built binary into cv2 package and ``__init__.py``
file in the package handles the import logic correctly.

Since both ``opencv-python`` and ``opencv-contrib-python`` use the same namespace explained above,
it is highly recommended to uninstall the other package before switching from example from
``opencv-python`` to ``opencv-contrib-python`` package.

Licensing
---------

Opencv-python package (scripts in this repository) is available under
MIT license.

OpenCV itself is available under `3-clause BSD
License <https://github.com/opencv/opencv/blob/master/LICENSE>`__
(`LICENSE-3RD-PARTY.txt <https://github.com/skvark/opencv-python/blob/master/LICENSE-3RD-PARTY.txt>`__).

All wheels ship with `FFmpeg <http://ffmpeg.org>`__ licensed under the `LGPLv2.1 <http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>`__.

Linux and MacOS wheels ship with `Qt 4.8.7 <http://doc.qt.io/qt-4.8/lgpl.html>`__ licensed under the `LGPLv2.1 <http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>`__.

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
