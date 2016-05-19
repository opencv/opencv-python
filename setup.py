from setuptools import setup
from setuptools.dist import Distribution
import pip
import os
import sys

opencv_version = ""

if "--opencv-version" in sys.argv:
    index = sys.argv.index('--opencv-version')
    sys.argv.pop(index)
    opencv_version = sys.argv.pop(index)
else:
    print("Error: no version info (--opencv-version missing), exiting.")
    exit(1)

numpy_version = ""

# Get required numpy version
for package in pip.get_installed_distributions():
    if package.key == "numpy":
        numpy_version = package.version

class BinaryDistribution(Distribution):
    """ Forces BinaryDistribution. """
    def has_ext_modules(asd):
        return True

package_data = {}

if os.name == 'posix':
    package_data['cv2'] = ['*.so']
else:
    package_data['cv2'] = ['*.pyd']

setup(name='opencv-python',
      version=opencv_version,
      description='OpenCV',
      distclass=BinaryDistribution,
      packages=['cv2'],
      package_data=package_data,
      install_requires="numpy==%s" % numpy_version,
      )