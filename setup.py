# No 3rd-party modules here, see "3rd-party" note below
import io, os, os.path, sys, runpy, subprocess, re, sysconfig


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    # Only import 3rd-party modules after having installed all the build dependencies:
    # any of them, or their dependencies, can be updated during that process,
    # leading to version conflicts
    numpy_version = get_or_install("numpy", "1.11.3" if sys.version_info[:2] >= (3, 6) else "1.11.1")
    get_or_install("scikit-build")
    import skbuild
    if os.path.isdir('.git'):
        import pip.vcs.git
        pip.vcs.git.Git().update_submodules('.')
        del pip


    # https://stackoverflow.com/questions/1405913/python-32bit-or-64bit-mode
    x64 = sys.maxsize>2**32

    build_contrib = get_build_contrib()

    package_name = "opencv-contrib-python" if build_contrib else "opencv-python"
    long_description = io.open('README_CONTRIB.rst' if build_contrib else 'README.rst', encoding="utf-8").read()
    package_version = get_opencv_version()

    package_data = \
        {'cv2':
            ['*%s' % sysconfig.get_config_var('SO')] + (['*.dll'] if os.name == 'nt' else []) +
            ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"]
         }

    # Files from CMake output to copy to package.
    # Path regexes with forward slashes relative to CMake install dir.
    rearrange_cmake_output_data = \
        {'cv2':
            sum([
                ([r'bin/opencv_ffmpeg\d{3}%s\.dll' %
                    ('_64' if x64 else '')] if os.name == 'nt' else []
                ),
                # In Windows, in python/X.Y/<arch>/; in Linux, in just python/X.Y/. What gives?
                ['python/([^/]+/){1,2}cv2%(arch)s%(ext)s' % {
                    'arch':  (('\\.cp%d%d-[^.]+' % sys.version_info[:2])
                               if sys.version_info[:2] >= (3, 5) else ''),	
                    'ext':   re.escape(sysconfig.get_config_var('SO'))
                    }
                ]
            ],[])
         }
    # Files in sourcetree outside package dir that should be copied to package.
    # Raw paths relative to sourcetree root.
    files_outside_package_dir = \
        {'cv2':
            ['LICENSE.txt', 'LICENSE-3RD-PARTY.txt']
         }

    cmake_source_dir = "opencv"
    cmake_args = ([
        "-G", "Visual Studio 14" + (" Win64" if x64 else '')
    ] if os.name == 'nt' else []) + \
    [
        # No need to specify Python paths, skbuild takes care of that
        "-DPYTHON%d_EXECUTABLE=%s" % (sys.version_info[0], sys.executable),
        "-DBUILD_opencv_python%d=ON" % sys.version_info[0],
        # Otherwise, opencv scripts would want to install `.pyd' right into site-packages,
        #  and skbuild bails out on seeing that
        "-DINSTALL_CREATE_DISTRIB=ON",
        # See opencv/CMakeLists.txt for options and defaults
        "-DBUILD_opencv_apps=OFF",
        "-DBUILD_SHARED_LIBS=OFF",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_PERF_TESTS=OFF",
        "-DBUILD_DOCS=OFF"
    ] + \
    ([ "-DOPENCV_EXTRA_MODULES_PATH=" + os.path.abspath("opencv_contrib/modules") ]
       if build_contrib else [])
    

    # ABI config variables are introduced in PEP 425
    if sys.version_info[:2] < (3, 2):
        import warnings
        warnings.filterwarnings('ignore', r"Config variable '[^']+' is unset, "
                                          r"Python ABI tag may be incorrect",
                                category=RuntimeWarning)
        del warnings


    # works via side effect
    RearrangeCMakeOutput(rearrange_cmake_output_data,
                         files_outside_package_dir,
                         package_data.keys())

    skbuild.setup(
        name=package_name,
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
        ],
        cmake_args=cmake_args,
        cmake_source_dir=cmake_source_dir,
          )


class RearrangeCMakeOutput(object):
    """Patch SKBuild logic to only take files related to the Python package
    and construct a file hierarchy that SKBuild expects (see below)"""
    _setuptools_wrap = None

    # Have to wrap a function reference, or it's converted
    # into an instance method on attr assignment
    import argparse
    wraps = argparse.Namespace(
        _classify_files=None)
    del argparse

    package_paths_re = None
    packages = None
    files_outside_package = None

    def __init__(self, package_paths_re, files_outside_package, packages):
        cls = self.__class__
        assert not cls.wraps._classify_files, "Singleton object"
        import skbuild.setuptools_wrap

        cls._setuptools_wrap = skbuild.setuptools_wrap
        cls.wraps._classify_files = cls._setuptools_wrap._classify_files
        cls._setuptools_wrap._classify_files = self._classify_files_override

        cls.package_paths_re = package_paths_re
        cls.files_outside_package = files_outside_package
        cls.packages = packages
    def __del__(self):
        cls = self.__class__
        cls._setuptools_wrap._classify_files = cls.wraps._classify_files
        cls.wraps._classify_files = None
        cls._setuptools_wrap = None

    def _classify_files_override(self, install_paths,
            package_data, package_prefixes,
            py_modules, new_py_modules,
            scripts, new_scripts,
            data_files,
            cmake_source_dir, cmake_install_reldir):
        """From all CMake output, we're only interested in a few files
        and must place them into CMake install dir according
        to Python conventions for SKBuild to find them:
            package\
                file
                subpackage\
                    etc.
        """
        cls = self.__class__
        # 'relpath'/'reldir' = relative to CMAKE_INSTALL_DIR/cmake_install_dir
        # 'path'/'dir' = relative to sourcetree root
        cmake_install_dir = os.path.join(cls._setuptools_wrap.CMAKE_INSTALL_DIR,
                                         cmake_install_reldir)
        install_relpaths = [os.path.relpath(p, cmake_install_dir) for p in install_paths]
        fslash_install_relpaths = [p.replace(os.path.sep, '/') for p in install_relpaths]
        relpaths_zip = list(zip(fslash_install_relpaths, install_relpaths))
        del install_relpaths, fslash_install_relpaths

        final_install_relpaths = []

        print("Copying files from CMake output")
        for package_name, relpaths_re in cls.package_paths_re.items():
            package_dest_reldir = package_name.replace('.', os.path.sep)
            for relpath_re in relpaths_re:
                found = False
                r = re.compile(relpath_re+'$')
                for fslash_relpath, relpath in relpaths_zip:
                    m = r.match(fslash_relpath)
                    if not m: continue
                    found = True
                    new_install_relpath = os.path.join(
                        package_dest_reldir,
                        os.path.basename(relpath))
                    cls._setuptools_wrap._copy_file(
                        os.path.join(cmake_install_dir, relpath),
                        os.path.join(cmake_install_dir, new_install_relpath),
                        hide_listing=False)
                    final_install_relpaths.append(new_install_relpath)
                    del m, fslash_relpath, new_install_relpath
                else:
                    if not found: raise Exception("Not found: '%s'" % relpath_re)
                del r, found

        del relpaths_zip

        print("Copying files from non-default sourcetree locations")
        for package_name, paths in cls.files_outside_package.items():
            package_dest_reldir = package_name.replace('.', os.path.sep)
            for path in paths:
                new_install_relpath = os.path.join(
                        package_dest_reldir,
                        # Don't yet have a need to copy
                        # to subdirectories of package dir
                        os.path.basename(path))
                cls._setuptools_wrap._copy_file(
                    path, os.path.join(cmake_install_dir, new_install_relpath),
                    hide_listing = False
                )
                final_install_relpaths.append(new_install_relpath)


        final_install_paths = [os.path.join(cmake_install_dir, p) for p in final_install_relpaths]

        return (cls.wraps._classify_files)(
            final_install_paths,
            package_data, package_prefixes,
            py_modules, new_py_modules,
            scripts, new_scripts,
            data_files,
            # To get around a demented check
            # that prepends source dir to paths and breaks package detection code.
            # Can't imagine what the authors were thinking that should be doing.
            cmake_source_dir = '',
            cmake_install_dir = cmake_install_reldir
            )


def install_packages(*requirements):
    # No more convenient way until PEP 518 is implemented; setuptools only handles eggs
    subprocess.check_call([sys.executable,
                           "-m", "pip", "install"]
                          + list(requirements))


def get_opencv_version():
    # cv_version.py should be generated by running find_version.py
    runpy.run_path("find_version.py")
    from cv_version import opencv_version
    return opencv_version


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


def get_or_install(name, version = None):
    """If a package is already installed, build against it. If not, install"""
    # Do not import 3rd-party modules into the current process
    import json
    js_packages = json.loads(
        subprocess.check_output(
        [sys.executable, "-m", "pip", "list", "--format=json"])
        .decode('ascii'))  #valid names & versions are ASCII as per PEP 440
    try:
        [package] = (package for package in js_packages
                     if package['name'] == name)
    except ValueError:
        install_packages("%s==%s"%(name, version) if version else name)
        return version
    else:
        return package['version']


# This creates a list which is empty but returns a length of 1.
# Should make the wheel a binary distribution and platlib compliant.
class EmptyListWithLength(list):
    def __len__(self):
        return 1


if __name__ == '__main__':
    main()
