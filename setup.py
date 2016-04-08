from setuptools import setup
import os
import sys

opencv_version = ""
binary_path = ""

if "--opencv-version" in sys.argv:
    index = sys.argv.index('--opencv-version')
    sys.argv.pop(index)
    opencv_version = sys.argv.pop(index)
else:
    print("Error: no version info (--opencv-version missing), exiting.")
    exit(1)

if "--binary-path" in sys.argv:
    index = sys.argv.index('--binary-path')
    sys.argv.pop(index)
    binary_path = sys.argv.pop(index)
else:
    print("Error: Binary path not provided (--binary-path missing), exiting.")
    exit(1)

package_data = {}

if os.name == 'posix':
    package_data['cv2'] = ['%s\*.so' % binary_path]
else:
    package_data['cv2'] = ['%s\*.pyd' % binary_path]

setup(name='opencv-python',
      version=opencv_version,
      description='OpenCV',
      packages=['cv2'],
      package_data=package_data,
      install_requires="numpy",
      )