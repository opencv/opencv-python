## What is `opencv-python-cuda`?

Pre-built NVIDIA® CUDA™ enabled OpenCV packages for Python that come with all batteries included. This is a fork of [the official opencv-python project](https://github.com/opencv/opencv-python). Right now packages are only produced for Windows x64, and devices must be Maxwell class (GeForce 900 series) or newer.  Once installed via `pip` (or another Python package manager like `uv`), the following should *just work*:

```
import cv2
print(cv2.cuda.getCudaEnabledDeviceCount())
```

### Installation and Usage

1. If you have previous/other manually installed (= not installed via ``pip``) version of OpenCV installed (e.g. cv2 module in the root of Python's site-packages), remove it before installation to avoid conflicts.
2. Make sure that your `pip` version is up-to-date (19.3 is the minimum supported version): `pip install --upgrade pip`. Check version with `pip -V`. For example Linux distributions ship usually with very old `pip` versions which cause a lot of unexpected problems especially with the `manylinux` format.
3. Download the latest build `opencv_python_cuda-*-win_amd64.whl` file and install it.
4. Import the `cv2` package as usual.

Frequently Asked Questions
--------------------------

Please refer to [the FAQ in the upstream project](https://github.com/opencv/opencv-python/?tab=readme-ov-file#frequently-asked-questions) for the most common questions.

**Q: How do I install `opencv-python-cuda`?**

A: Releases can be downloaded from [the Releases page](https://github.com/Breakthrough/opencv-python-cuda/releases). You can download and install the pre-built Python .whl file with `pip install`.

**Q: Can you upload `opencv-python-cuda` to PyPI?**

A: No, the package is far too large and exceeds [project size limits](https://docs.pypi.org/project-management/storage-limits/).

**Q: What do the wheels include?**

All OpenCV modules that can be enabled with CUDA. All required runtime files are included in the wheels. Non-free algorithms are excluded as per the following question.

**Q: Why are non-free algorithms excluded?**

A: Non-free algorithms such as SURF are not included in these packages because they are patented / non-free and therefore cannot be distributed as built binaries. Note that SIFT is included in the builds due to patent expiration since OpenCV versions 4.3.0 and 3.4.10. See this issue for more info: https://github.com/skvark/opencv-python/issues/126

### Licensing

Opencv-python-cuda package (scripts in this repository) is available under MIT license.

OpenCV itself is available under [Apache 2](https://github.com/opencv/opencv/blob/master/LICENSE) license.

Third party package licenses are at [LICENSE-3RD-PARTY.txt](https://github.com/opencv/opencv-python/blob/master/LICENSE-3RD-PARTY.txt).

All wheels are distributed with [FFmpeg](http://ffmpeg.org) licensed under the [LGPLv2.1](http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html), and redistributable portions of the NVIDIA® CUDA™ SDK under the [NVIDIA Software License Agreement (EULA)](https://docs.nvidia.com/cuda/eula/index.html).

Non-headless Linux wheels ship with [Qt 5](http://doc.qt.io/qt-5/lgpl.html) licensed under the [LGPLv3](http://www.gnu.org/licenses/lgpl-3.0.html).

The packages include also other binaries. Full list of licenses can be found from [LICENSE-3RD-PARTY.txt](https://github.com/opencv/opencv-python/blob/master/LICENSE-3RD-PARTY.txt).

### Supported Python versions

Python 3.x compatible pre-built wheels are provided for the officially supported Python versions (not in EOL):

- 3.7
- 3.8
- 3.9
- 3.10
- 3.11
- 3.12
- 3.13
