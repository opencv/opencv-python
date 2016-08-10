import sys
import os
import subprocess

opencv_version = ""
# dig out the version from OpenCV sources
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

# used in local dev releases
git_hash = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).splitlines()[0].decode()

if os.name == 'posix':
    version = os.getenv('TRAVIS_TAG', git_hash)
else:
    version = os.getenv('APPVEYOR_REPO_TAG_NAME', git_hash)

if version != git_hash:
    # tag identifies the build and should be a sequential revision number
    opencv_version += ".{}".format(version)
else:
    # local version identifier, not to be published on PyPI
    opencv_version += "+{}".format(version)

print("Version: ", opencv_version)

with open('cv_version.py', 'w') as f:
    f.write('opencv_version = "{}"'.format(opencv_version))
