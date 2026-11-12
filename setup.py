import io
import os
import os.path
import sys
import runpy
import subprocess
import re
import sysconfig
import platform
from skbuild import setup


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    CI_BUILD = os.environ.get("CI_BUILD", "False")
    is_CI_build = True if CI_BUILD == "1" else False
    cmake_source_dir = "opencv"
    minimum_supported_numpy = "1.13.3"
    build_contrib = get_build_env_var_by_name("contrib")
    build_headless = get_build_env_var_by_name("headless")
    build_java = "ON" if get_build_env_var_by_name("java") else "OFF"
    build_rolling = get_build_env_var_by_name("rolling")

    install_requires = [
        'numpy<2.0; python_version<"3.9"',
        'numpy>=2; python_version>="3.9"',
    ]

    python_version = sysconfig.get_config_var("py_version_short")
    python_lib_path = get_python_library(python_version).replace("\\", "/")
    python_include_dir = sysconfig.get_paths()["include"].replace("\\", "/")

    if not bool(os.environ.get('OPENCV_PYTHON_SKIP_GIT_COMMANDS', False)) and os.path.exists(".git"):
        import pip._internal.vcs.git as git

        g = git.Git()  # NOTE: pip API's are internal, this has to be refactored

        g.run_command(["submodule", "sync"])

        if build_rolling:
            g.run_command(
                ["submodule", "update", "--init", "--recursive", "--remote", cmake_source_dir]
            )

            if build_contrib:
                g.run_command(
                    ["submodule", "update", "--init", "--recursive", "--remote", "opencv_contrib"]
                )
        else:
            g.run_command(
                ["submodule", "update", "--init", "--recursive", cmake_source_dir]
            )

            if build_contrib:
                g.run_command(
                    ["submodule", "update", "--init", "--recursive", "opencv_contrib"]
                )

    package_version, build_contrib, build_headless, build_rolling = get_and_set_info(
        build_contrib, build_headless, build_rolling, is_CI_build
    )

    # https://stackoverflow.com/questions/1405913/python-32bit-or-64bit-mode
    is64 = sys.maxsize > 2 ** 32

    package_name = "opencv_python"

    if build_contrib and not build_headless:
        package_name = "opencv_contrib_python"

    if build_contrib and build_headless:
        package_name = "opencv_contrib_python_headless"

    if build_headless and not build_contrib:
        package_name = "opencv_python_headless"

    if build_rolling:
        package_name += "-rolling"

    package_name = os.environ.get('OPENCV_PYTHON_PACKAGE_NAME', package_name)

    long_description = io.open("README.md", encoding="utf-8").read()

    packages = ["cv2", "cv2.data"]

    package_data = {
        "cv2": ["*%s" % sysconfig.get_config_vars().get("SO"), "version.py"]
        + (["*.dll"] if os.name == "nt" else [])
        + ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"],
        "cv2.data": ["*.xml"],
    }

    ci_cmake_generator = (
        ["-G", "Visual Studio 17 2022"]
        if os.name == "nt"
        else ["-G", "Unix Makefiles"]
    )

    cmake_args = (
        (ci_cmake_generator if is_CI_build else [])
        + [
            # skbuild inserts PYTHON_* vars. That doesn't satisfy opencv build scripts in case of Py3
            "-DPYTHON3_EXECUTABLE=%s" % sys.executable,
            "-DPYTHON_DEFAULT_EXECUTABLE=%s" % sys.executable,
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
            # Installs the cv2 package layout, see cmake/package
            "-DOPENCV_CMAKE_HOOKS_DIR=%s" % os.path.abspath("cmake/hooks").replace("\\", "/"),
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
        # see: https://github.com/skvark/opencv-python/issues/263
        # see: https://github.com/opencv/opencv-python/issues/771
        cmake_args.append("-DWITH_MSMF=OFF")
        cmake_args.append("-DWITH_OBSENSOR=OFF") # Orbbec cameras backend uses MSMF API
        # see: https://github.com/opencv/opencv/issues/28438
        # libavdevice is enabled by default, but brings libxcb dependency
        if sys.platform.startswith("linux"):
            cmake_args.append("-DOPENCV_FFMPEG_ENABLE_LIBAVDEVICE=OFF")

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
            cmake_args.append("-DWITH_V4L=ON")
            cmake_args.append("-DWITH_LAPACK=ON")
            cmake_args.append("-DENABLE_PRECOMPILED_HEADERS=OFF")

    setup(
        name=package_name,
        version=package_version,
        url="https://github.com/opencv/opencv-python",
        license="Apache 2.0",
        description="Wrapper package for OpenCV python bindings.",
        long_description=long_description,
        long_description_content_type="text/markdown",
        packages=packages,
        package_data=package_data,
        maintainer="OpenCV Team",
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
            "License :: OSI Approved :: Apache Software License",
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
            "Programming Language :: Python :: 3.11",
            "Programming Language :: Python :: 3.12",
            "Programming Language :: Python :: 3.13",
            "Programming Language :: Python :: 3.14",
            "Programming Language :: C++",
            "Programming Language :: Python :: Implementation :: CPython",
            "Topic :: Scientific/Engineering",
            "Topic :: Scientific/Engineering :: Image Recognition",
            "Topic :: Software Development",
        ],
        cmake_args=cmake_args,
        cmake_source_dir=cmake_source_dir,
        cmake_process_manifest_hook=keep_package_files,
    )

    print("OpenCV is raising funds to keep the library free for everyone, and we need the support of the entire community to do it. Donate to OpenCV on GitHub:\nhttps://github.com/sponsors/opencv\n")

def get_python_library(python_version):
    if os.name == "nt":
        return os.path.join(
            sys.base_prefix, "libs", "python%s.lib" % python_version.replace(".", "")
        )
    libdir = sysconfig.get_config_var("LIBDIR")
    ldlibrary = sysconfig.get_config_var("LDLIBRARY")
    if libdir and ldlibrary and os.path.exists(os.path.join(libdir, ldlibrary)):
        return os.path.join(libdir, ldlibrary)
    # No libpython (like manylinux); extension modules must not link to it anyway
    return "libpython%sm.a" % python_version


def keep_package_files(cmake_manifest):
    """
        Only keep the cv2 package assembled by cmake/package, dropping the
        rest of the OpenCV install. Paths are relative to the install dir
        (scikit-build 1.0) or to the source dir (older scikit-build).
    """
    return [
        p for p in cmake_manifest
        if re.match(r"(.*/cmake-install/)?cv2/", p.replace(os.path.sep, "/"))
    ]


def get_and_set_info(contrib, headless, rolling, ci_build):
    # cv2/version.py should be generated by running find_version.py
    version = {}
    here = os.path.abspath(os.path.dirname(__file__))
    version_file = os.path.join(here, "cv2", "version.py")

    # generate a fresh version.py always when Git repository exists
    # (in sdists the version.py file already exists)
    if os.path.exists(".git"):
        old_args = sys.argv.copy()
        sys.argv = ["", str(contrib), str(headless), str(rolling), str(ci_build)]
        runpy.run_path("find_version.py", run_name="__main__")
        sys.argv = old_args

    with open(version_file) as fp:
        exec(fp.read(), version)

    return version["opencv_version"], version["contrib"], version["headless"], version["rolling"]


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
