import io, os, os.path, sys, runpy, subprocess

import pip


def main():
    build_contrib = get_build_contrib()

    package_name = "opencv-contrib-python" if build_contrib else "opencv-python"
    long_description = io.open('README_CONTRIB.rst' if build_contrib else 'README.rst', encoding="utf-8").read()
    package_version = get_opencv_version()
    numpy_version = get_or_install_numpy_version("1.11.3" if sys.version_info[:2] >= (3, 6) else "1.11.1")
    package_data = \
        {'cv2':
             (['*.so'] if os.name == 'posix' else ['*.pyd', '*.dll'])
             + ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"]
         }

    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    if sys.version_info[:2] < (3, 2):
        import warnings
        # ABI config variables are introduced in PEP 425
        warnings.filterwarnings('ignore', r"Config variable '[^']+' is unset, Python ABI tag may be incorrect",
                                category=RuntimeWarning)

    setup(name=package_name,
          version=package_version,
          url='https://github.com/skvark/opencv-python',
          license='MIT',
          description='Wrapper package for OpenCV python bindings.',
          long_description=long_description,
          packages=['cv2'],
          package_data=package_data,
          maintainer="Olli-Pekka Heinisuo",
          include_package_data=True,
          ext_modules=EmptyListWithLength(),
          install_requires="numpy>=%s" % numpy_version,
          classifiers=[
              'Development Status :: 5 - Production/Stable',
              'Environment :: Console',
              'Intended Audience :: Developers',
              'Intended Audience :: Education',
              'Intended Audience :: Information Technology',
              'Intended Audience :: Science/Research',
              'License :: OSI Approved :: MIT License',
              'Operating System :: MacOS',
              'Operating System :: Microsoft :: Windows',
              'Operating System :: POSIX',
              'Operating System :: Unix',
              'Programming Language :: Python',
              'Programming Language :: C++',
              'Programming Language :: Python :: Implementation :: CPython',
              'Topic :: Scientific/Engineering',
              'Topic :: Scientific/Engineering :: Image Recognition',
              'Topic :: Software Development',
          ]
          )


def install_packages(*requirements):
    # No more convenient way until PEP 518 is implemented
    subprocess.check_call([sys.executable,
                           "-m", "pip", "install"]
                          + list(requirements))


def get_opencv_version():
    # cv_version.py should be generated by running find_version.py
    runpy.run_path("find_version.py")
    from cv_version import opencv_version
    return opencv_version

package_data[''] = ['*.xml']

def get_build_contrib():
    build_contrib = False
    try:
        build_contrib = bool(int(os.getenv('ENABLE_CONTRIB', None)))
    except Exception:
        pass

    if not build_contrib:
        print("Trying to read contrib enable flag from file...")
        try:
            build_contrib = bool(int(open("contrib.enabled").read(1)))
        except Exception:
            pass
    return build_contrib


def get_or_install_numpy_version(version_to_install):
    """If numpy is already installed, build against it. If not, install"""
    try:
        [package] = (package for package in pip.get_installed_distributions()
                     if package.key == "numpy")
        return package.version
    except IndexError:
        install_packages("numpy==%s" % version_to_install)
        return version_to_install


# This creates a list which is empty but returns a length of 1.
# Should make the wheel a binary distribution and platlib compliant.
class EmptyListWithLength(list):
    def __len__(self):
        return 1


if __name__ == '__main__':
    main()
