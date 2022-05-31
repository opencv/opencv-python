import io
import os
import os.path
import sys
import runpy
import subprocess
import re
import sysconfig
import platform
import skbuild
from skbuild import cmaker


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    CI_BUILD = os.environ.get("CI_BUILD", "False")
    is_CI_build = True if CI_BUILD == "1" else False
    cmake_source_dir = "opencv"
    minimum_supported_numpy = "1.13.3"
    build_contrib = get_build_env_var_by_name("contrib")
    build_headless = get_build_env_var_by_name("headless")
    build_java = "ON" if get_build_env_var_by_name("java") else "OFF"

    install_requires = [
        'numpy>=1.13.3; python_version<"3.7"',
        'numpy>=1.14.5; python_version>="3.7"',
        'numpy>=1.17.3; python_version>="3.8"',
        'numpy>=1.19.3; python_version>="3.9"',
        'numpy>=1.21.2; python_version>="3.10"',
        'numpy>=1.19.3; python_version>="3.6" and platform_system=="Linux" and platform_machine=="aarch64"',
        'numpy>=1.21.2; python_version>="3.6" and platform_system=="Darwin" and platform_machine=="arm64"',
    ]

    python_version = cmaker.CMaker.get_python_version()
    python_lib_path = cmaker.CMaker.get_python_library(python_version).replace(
        "\\", "/"
    )
    python_include_dir = cmaker.CMaker.get_python_include_dir(python_version).replace(
        "\\", "/"
    )

    if os.path.exists(".git"):
        import pip._internal.vcs.git as git

        g = git.Git()  # NOTE: pip API's are internal, this has to be refactored

        g.run_command(["submodule", "sync"])
        g.run_command(
            ["submodule", "update", "--init", "--recursive", cmake_source_dir]
        )

        if build_contrib:
            g.run_command(
                ["submodule", "update", "--init", "--recursive", "opencv_contrib"]
            )

    package_version, build_contrib, build_headless = get_and_set_info(
        build_contrib, build_headless, is_CI_build
    )

    # https://stackoverflow.com/questions/1405913/python-32bit-or-64bit-mode
    is64 = sys.maxsize > 2 ** 32

    package_name = "opencv-python"

    if build_contrib and not build_headless:
        package_name = "opencv-contrib-python"

    if build_contrib and build_headless:
        package_name = "opencv-contrib-python-headless"

    if build_headless and not build_contrib:
        package_name = "opencv-python-headless"

    long_description = io.open("README.md", encoding="utf-8").read()

    packages = ["cv2", "cv2.data"]

    package_data = {
        "cv2": ["*%s" % sysconfig.get_config_vars().get("SO"), "version.py"]
        + (["*.dll"] if os.name == "nt" else [])
        + ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"],
        "cv2.data": ["*.xml"],
    }

    # Files from CMake output to copy to package.
    # Path regexes with forward slashes relative to CMake install dir.
    rearrange_cmake_output_data = {
        "cv2": (
            [r"bin/opencv_ffmpeg\d{3,4}%s\.dll" % ("_64" if is64 else "")]
            if os.name == "nt"
            else []
        )
        +
        # In Windows, in python/X.Y/<arch>/; in Linux, in just python/X.Y/.
        # Naming conventions vary so widely between versions and OSes
        # had to give up on checking them.
        [
            r"python/cv2/python-%s/cv2.*"
            % (sys.version_info[0])
        ]
        +
        [
            r"python/cv2/__init__.py"
        ]
        +
        [
            r"python/cv2/.*config.*.py"
        ],
        "cv2.data": [  # OPENCV_OTHER_INSTALL_PATH
            ("etc" if os.name == "nt" else "share/OpenCV") + r"/haarcascades/.*\.xml"
        ],
    }

    # Files in sourcetree outside package dir that should be copied to package.
    # Raw paths relative to sourcetree root.
    files_outside_package_dir = {"cv2": ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"]}

    ci_cmake_generator = (
        ["-G", "Visual Studio 14" + (" Win64" if is64 else "")]
        if os.name == "nt"
        else ["-G", "Unix Makefiles"]
    )

    cmake_args = (
        (ci_cmake_generator if is_CI_build else [])
        + [
            # skbuild inserts PYTHON_* vars. That doesn't satisfy opencv build scripts in case of Py3
            "-DPYTHON3_EXECUTABLE=%s" % sys.executable,
            "-DPYTHON3_INCLUDE_DIR=%s" % python_include_dir,
            "-DPYTHON3_LIBRARY=%s" % python_lib_path,
            "-DBUILD_opencv_python3=ON",
            "-DBUILD_opencv_python2=OFF",
            # Disable the Java build by default as it is not needed
            "-DBUILD_opencv_java=%s" % build_java,
            # Relative dir to install the built module to in the build tree.
            # The default is generated from sysconfig, we'd rather have a constant for simplicity
            "-DOPENCV_PYTHON3_INSTALL_PATH=python",
            # Otherwise, opencv scripts would want to install `.pyd' right into site-packages,
            # and skbuild bails out on seeing that
            "-DINSTALL_CREATE_DISTRIB=ON",
            # See opencv/CMakeLists.txt for options and defaults
            "-DBUILD_opencv_apps=OFF",
            "-DBUILD_opencv_freetype=OFF",
            "-DBUILD_SHARED_LIBS=OFF",
            "-DBUILD_TESTS=OFF",
            "-DBUILD_PERF_TESTS=OFF",
            "-DBUILD_DOCS=OFF",
            "-DPYTHON3_LIMITED_API=ON",
            "-DBUILD_OPENEXR=ON",
        ]
        + (
            # CMake flags for windows/arm64 build
            ["-DCMAKE_GENERATOR_PLATFORM=ARM64",
             # Emulated cmake requires following flags to correctly detect
             # target architecture for windows/arm64 build
             "-DOPENCV_WORKAROUND_CMAKE_20989=ON",
             "-DCMAKE_SYSTEM_PROCESSOR=ARM64"]
            if platform.machine() == "ARM64" and sys.platform == "win32"
            # If it is not defined 'linker flags: /machine:X86' on Windows x64
            else ["-DCMAKE_GENERATOR_PLATFORM=x64"] if is64 and sys.platform == "win32"
            else []
          )
        + (
            ["-DOPENCV_EXTRA_MODULES_PATH=" + os.path.abspath("opencv_contrib/modules")]
            if build_contrib
            else []
        )
    )

    if build_headless:
        # it seems that cocoa cannot be disabled so on macOS the package is not truly headless
        cmake_args.append("-DWITH_WIN32UI=OFF")
        cmake_args.append("-DWITH_QT=OFF")
        cmake_args.append("-DWITH_GTK=OFF")
        if is_CI_build:
            cmake_args.append(
                "-DWITH_MSMF=OFF"
            )  # see: https://github.com/skvark/opencv-python/issues/263

    if sys.platform.startswith("linux") and not is64 and "bdist_wheel" in sys.argv:
        subprocess.check_call("patch -p0 < patches/patchOpenEXR", shell=True)

    # OS-specific components during CI builds
    if is_CI_build:

        if (
            not build_headless
            and "bdist_wheel" in sys.argv
            and sys.platform.startswith("linux")
        ):
            cmake_args.append("-DWITH_QT=5")
            subprocess.check_call("patch -p1 < patches/patchQtPlugins", shell=True)

            if sys.platform.startswith("linux"):
                rearrange_cmake_output_data["cv2.qt.plugins.platforms"] = [
                    (r"lib/qt/plugins/platforms/libqxcb\.so")
                ]

                # add fonts for Qt5
                fonts = []
                for file in os.listdir("/usr/share/fonts/dejavu"):
                    if file.endswith(".ttf"):
                        fonts.append(
                            (r"lib/qt/fonts/dejavu/%s\.ttf" % file.split(".")[0])
                        )

                rearrange_cmake_output_data["cv2.qt.fonts"] = fonts

            if sys.platform == "darwin":
                rearrange_cmake_output_data["cv2.qt.plugins.platforms"] = [
                    (r"lib/qt/plugins/platforms/libqcocoa\.dylib")
                ]

        if sys.platform.startswith("linux"):
            cmake_args.append("-DWITH_V4L=ON")
            cmake_args.append("-DWITH_LAPACK=ON")
            cmake_args.append("-DENABLE_PRECOMPILED_HEADERS=OFF")

    # https://github.com/scikit-build/scikit-build/issues/479
    if "CMAKE_ARGS" in os.environ:
        import shlex

        cmake_args.extend(shlex.split(os.environ["CMAKE_ARGS"]))
        del shlex

    # works via side effect
    RearrangeCMakeOutput(
        rearrange_cmake_output_data, files_outside_package_dir, package_data.keys()
    )

    skbuild.setup(
        name=package_name,
        version=package_version,
        url="https://github.com/skvark/opencv-python",
        license="MIT",
        description="Wrapper package for OpenCV python bindings.",
        long_description=long_description,
        long_description_content_type="text/markdown",
        packages=packages,
        package_data=package_data,
        maintainer="Olli-Pekka Heinisuo",
        ext_modules=EmptyListWithLength(),
        install_requires=install_requires,
        python_requires=">=3.6",
        classifiers=[
            "Development Status :: 5 - Production/Stable",
            "Environment :: Console",
            "Intended Audience :: Developers",
            "Intended Audience :: Education",
            "Intended Audience :: Information Technology",
            "Intended Audience :: Science/Research",
            "License :: OSI Approved :: MIT License",
            "Operating System :: MacOS",
            "Operating System :: Microsoft :: Windows",
            "Operating System :: POSIX",
            "Operating System :: Unix",
            "Programming Language :: Python",
            "Programming Language :: Python :: 3",
            "Programming Language :: Python :: 3 :: Only",
            "Programming Language :: Python :: 3.6",
            "Programming Language :: Python :: 3.7",
            "Programming Language :: Python :: 3.8",
            "Programming Language :: Python :: 3.9",
            "Programming Language :: Python :: 3.10",
            "Programming Language :: C++",
            "Programming Language :: Python :: Implementation :: CPython",
            "Topic :: Scientific/Engineering",
            "Topic :: Scientific/Engineering :: Image Recognition",
            "Topic :: Software Development",
        ],
        cmake_args=cmake_args,
        cmake_source_dir=cmake_source_dir,
    )


class RearrangeCMakeOutput(object):
    """
        Patch SKBuild logic to only take files related to the Python package
        and construct a file hierarchy that SKBuild expects (see below)
    """

    _setuptools_wrap = None

    # Have to wrap a function reference, or it's converted
    # into an instance method on attr assignment
    import argparse

    wraps = argparse.Namespace(_classify_installed_files=None)
    del argparse

    package_paths_re = None
    packages = None
    files_outside_package = None

    def __init__(self, package_paths_re, files_outside_package, packages):
        cls = self.__class__
        assert not cls.wraps._classify_installed_files, "Singleton object"
        import skbuild.setuptools_wrap

        cls._setuptools_wrap = skbuild.setuptools_wrap
        cls.wraps._classify_installed_files = (
            cls._setuptools_wrap._classify_installed_files
        )
        cls._setuptools_wrap._classify_installed_files = (
            self._classify_installed_files_override
        )

        cls.package_paths_re = package_paths_re
        cls.files_outside_package = files_outside_package
        cls.packages = packages

    def __del__(self):
        cls = self.__class__
        cls._setuptools_wrap._classify_installed_files = (
            cls.wraps._classify_installed_files
        )
        cls.wraps._classify_installed_files = None
        cls._setuptools_wrap = None

    def _classify_installed_files_override(
        self,
        install_paths,
        package_data,
        package_prefixes,
        py_modules,
        new_py_modules,
        scripts,
        new_scripts,
        data_files,
        cmake_source_dir,
        cmake_install_reldir,
    ):
        """
            From all CMake output, we're only interested in a few files
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
        cmake_install_dir = os.path.join(
            cls._setuptools_wrap.CMAKE_INSTALL_DIR(), cmake_install_reldir
        )
        install_relpaths = [
            os.path.relpath(p, cmake_install_dir) for p in install_paths
        ]
        fslash_install_relpaths = [
            p.replace(os.path.sep, "/") for p in install_relpaths
        ]
        relpaths_zip = list(zip(fslash_install_relpaths, install_relpaths))
        del install_relpaths, fslash_install_relpaths

        final_install_relpaths = []

        print("Copying files from CMake output")

        # add lines from the old __init__.py file to the config file
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts', '__init__.py'), 'r') as custom_init:
            custom_init_data = custom_init.read()
        with open('%spython/cv2/config-%s.py'
        % (cmake_install_dir, sys.version_info[0]), 'w') as opencv_init_config:
            opencv_init_config.write(custom_init_data)

        for package_name, relpaths_re in cls.package_paths_re.items():
            package_dest_reldir = package_name.replace(".", os.path.sep)
            for relpath_re in relpaths_re:
                found = False
                r = re.compile(relpath_re + "$")
                for fslash_relpath, relpath in relpaths_zip:
                    m = r.match(fslash_relpath)
                    if not m:
                        continue
                    found = True
                    new_install_relpath = os.path.join(
                        package_dest_reldir, os.path.basename(relpath)
                    )
                    cls._setuptools_wrap._copy_file(
                        os.path.join(cmake_install_dir, relpath),
                        os.path.join(cmake_install_dir, new_install_relpath),
                        hide_listing=False,
                    )
                    final_install_relpaths.append(new_install_relpath)
                    del m, fslash_relpath, new_install_relpath
                else:
                    # gapi can be missed if ADE was not downloaded (network issue)
                    if not found and "gapi" not in relpath_re:
                        raise Exception("Not found: '%s'" % relpath_re)
                del r, found

        del relpaths_zip

        print("Copying files from non-default sourcetree locations")

        for package_name, paths in cls.files_outside_package.items():
            package_dest_reldir = package_name.replace(".", os.path.sep)
            for path in paths:
                new_install_relpath = os.path.join(
                    package_dest_reldir,
                    # Don't yet have a need to copy
                    # to subdirectories of package dir
                    os.path.basename(path),
                )
                cls._setuptools_wrap._copy_file(
                    path,
                    os.path.join(cmake_install_dir, new_install_relpath),
                    hide_listing=False,
                )
                final_install_relpaths.append(new_install_relpath)

        final_install_paths = [
            os.path.join(cmake_install_dir, p) for p in final_install_relpaths
        ]

        return (cls.wraps._classify_installed_files)(
            final_install_paths,
            package_data,
            package_prefixes,
            py_modules,
            new_py_modules,
            scripts,
            new_scripts,
            data_files,
            # To get around a check that prepends source dir to paths and breaks package detection code.
            cmake_source_dir="",
            _cmake_install_dir=cmake_install_reldir,
        )


def get_and_set_info(contrib, headless, ci_build):
    # cv2/version.py should be generated by running find_version.py
    version = {}
    here = os.path.abspath(os.path.dirname(__file__))
    version_file = os.path.join(here, "cv2", "version.py")

    # generate a fresh version.py always when Git repository exists
    # (in sdists the version.py file already exists)
    if os.path.exists(".git"):
        old_args = sys.argv.copy()
        sys.argv = ["", str(contrib), str(headless), str(ci_build)]
        runpy.run_path("find_version.py", run_name="__main__")
        sys.argv = old_args

    with open(version_file) as fp:
        exec(fp.read(), version)

    return version["opencv_version"], version["contrib"], version["headless"]


def get_build_env_var_by_name(flag_name):
    flag_set = False

    try:
        flag_set = bool(int(os.getenv("ENABLE_" + flag_name.upper(), None)))
    except Exception:
        pass

    if not flag_set:
        try:
            flag_set = bool(int(open(flag_name + ".enabled").read(1)))
        except Exception:
            pass

    return flag_set


# This creates a list which is empty but returns a length of 1.
# Should make the wheel a binary distribution and platlib compliant.
class EmptyListWithLength(list):
    def __len__(self):
        return 1


if __name__ == "__main__":
    main()
