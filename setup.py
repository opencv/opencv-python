from setuptools import setup
from setuptools.dist import Distribution
import pip
import os
import sys

numpy_version = ""

# Get required numpy version
for package in pip.get_installed_distributions():
    if package.key == "numpy":
        numpy_version = package.version

opencv_version = ""
# dig the version from OpenCV sources
version_file_path = "opencv/modules/core/include/opencv2/core/version.hpp"

with open(version_file_path, 'r') as f:
    for line in f:
        words = line.split()

        if "CV_VERSION_MAJOR" in words:
            opencv_version += words[2]
            opencv_version += "."

        if "CV_VERSION_MINOR" in words:
            opencv_version += words[2]
            opencv_version += "."

        if "CV_VERSION_REVISION" in words:
            opencv_version += words[2]
            break


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