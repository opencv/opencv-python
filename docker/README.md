### Customized manylinux images for opencv-python

The subfolders include Dockerfiles for extending both ``i686`` and ``x86_64`` manylinux1 and manylinux2014 images.

Manylinux2014 is used in wheels with version 3.4.10.* / 4.3.0.* and above. 

The extended images were created to be able to build OpenCV in reasonable time with Travis. The images are hosted at https://quay.io/user/skvark.

See the dockerfiles for more info.
