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
# this outputs the annotated tag if we are exactly on a tag, otherwise <tag>-<n>-g<shortened sha-1>
tag = subprocess.check_output(['git', 'describe', '--tags']).splitlines()[0].decode().split('-')

if len(tag) == 1:
    # tag identifies the build and should be a sequential revision number
    version = tag[0]
    opencv_version += ".{}".format(version)
else:
    # local version identifier, not to be published on PyPI
    version = git_hash
    opencv_version += "+{}".format(version)

print("Version: ", opencv_version)

with open('cv_version.py', 'w') as f:
    f.write('opencv_version = "{}"'.format(opencv_version))
