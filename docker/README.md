### Customized manylinux images for opencv-python

This folder includes Dockerfiles for extending both ``i686`` and ``x86_64`` manylinux images.

The extended images were created to be able to build OpenCV in reasonable time with Travis. The images are hosted at https://quay.io/user/skvark.

The images have following extra software installed:

- Qt 4.8.7
- Cmake 3.9.0
- FFmpeg with libvpx (latest snapshots at the build time) and recent openssl + other FFmpeg dependencies built from sources
- Some missing headers included from more recent Linux to be able to enable V4L / V4L2 support in OpenCV