from setuptools import setup
import os
import sys

opencv_version = ""

if "--opencv_version" in sys.argv:
    index = sys.argv.index('--opencv-version')
    sys.argv.pop(index)
    opencv_version = sys.argv.pop(index)
else:
    print("Error: no version info (--opencv-version missing), exiting.")
    exit(1)

package_data = {}

if os.name == 'posix':
    package_data['cv2'] = ['*.so']
else:
    package_data['cv2'] = ['*.pyd']

setup(name='opencv-python',
      version=opencv_version,
      description='OpenCV',
      packages=['cv2'],
      package_data=package_data,
      install_requires="numpy",
      )