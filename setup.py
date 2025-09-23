import io
import os
import os.path
import sys
import runpy
import subprocess
import re
import sysconfig
import platform
from skbuild import cmaker, setup

def is_free_threaded_python():
    exe_name = os.path.basename(sys.executable)
    # Python 3.14 free-threaded ends with "t" or "t.exe"
    return exe_name.endswith("t.exe") or exe_name.endswith("t")

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
        'numpy(>=2, <2.3.0); python_version>="3.9"',
    ]

    python_version = cmaker.CMaker.get_python_version()
    python_lib_path = cmaker.CMaker.get_python_library(python_version) or ""
    if python_lib_path == "":
        python_lib_path = "libpython%sm.a" % python_version
    python_lib_path = python_lib_path.replace("\\", "/")

    python_include_dir = cmaker.CMaker.get_python_include_dir(python_version).replace("\\", "/")

    if not bool(os.environ.get('OPENCV_PYTHON_SKIP_GIT_COMMANDS', False)) and os.path.exists(".git"):
        import pip._internal.vcs.git as git
        g = git.Git()
        g.run_command(["submodule", "sync"])
        if build_rolling:
            g.run_command(["submodule", "update", "--init", "--recursive", "--remote", cmake_source_dir])
            if build_contrib:
                g.run_command(["submodule", "update", "--init", "--recursive", "--remote", "opencv_contrib"])
        else:
            g.run_command(["submodule", "update", "--init", "--recursive", cmake_source_dir])
            if build_contrib:
                g.run_command(["submodule", "update", "--init", "--recursive", "opencv_contrib"])

    package_version, build_contrib, build_headless, build_rolling = get_and_set_info(
        build_contrib, build_headless, build_rolling, is_CI_build
    )

    is64 = sys.maxsize > 2 ** 32

    package_name = "opencv-python"
    if build_contrib and not build_headless:
        package_name = "opencv-contrib-python"
    if build_contrib and build_headless:
        package_name = "opencv-contrib-python-headless"
    if build_headless and not build_contrib:
        package_name = "opencv-python-headless"
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

    rearrange_cmake_output_data = {
        "cv2": (
            [r"bin/opencv_videoio_ffmpeg\d{4}%s\.dll" % ("_64" if is64 else "")]
            if os.name == "nt"
            else []
        )
        +
        [
            r"python/cv2/__init__.py",
            r"python/cv2/.*config.*.py",
        ]
        +
        [
            r"python/cv2/py.typed"
        ] if sys.version_info >= (3, 6) else [],
        "cv2.data": [
            ("etc" if os.name == "nt" else "share/opencv4") + r"/haarcascades/.*\.xml"
        ],
        "cv2.gapi": [
            "python/cv2" + r"/gapi/.*\.py"
        ],
        "cv2.mat_wrapper": [
            "python/cv2" + r"/mat_wrapper/.*\.py"
        ],
        "cv2.misc": [
            "python/cv2" + r"/misc/.*\.py"
        ],
        "cv2.utils": [
            "python/cv2" + r"/utils/.*\.py"
        ],
    }
    if sys.version_info >= (3, 6):
        rearrange_cmake_output_data["cv2.typing"] = ["python/cv2" + r"/typing/.*\.py"]

    files_outside_package_dir = {"cv2": ["LICENSE.txt", "LICENSE-3RD-PARTY.txt"]}

    ci_cmake_generator = (
        ["-G", "Visual Studio 17 2022"]
        if os.name == "nt"
        else ["-G", "Unix Makefiles"]
    )

    cmake_args = (
        (ci_cmake_generator if is_CI_build else [])
        + [
            "-DPYTHON3_EXECUTABLE=%s" % sys.executable,
            "-DPYTHON_DEFAULT_EXECUTABLE=%s" % sys.executable,
            "-DPYTHON3_INCLUDE_DIR=%s" % python_include_dir,
            "-DPYTHON3_LIBRARY=%s" % python_lib_path,
            "-DBUILD_opencv_python3=ON",
            "-DBUILD_opencv_python2=OFF",
            "-DBUILD_opencv_java=%s" % build_java,
            "-DOPENCV_PYTHON3_INSTALL_PATH=python",
            "-DINSTALL_CREATE_DISTRIB=ON",
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
            ["-DCMAKE_GENERATOR_PLATFORM=ARM64",
             "-DOPENCV_WORKAROUND_CMAKE_20989=ON",
             "-DCMAKE_SYSTEM_PROCESSOR=ARM64"]
            if platform.machine() == "ARM64" and sys.platform == "win32"
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
        cmake_args.append("-DWITH_WIN32UI=OFF")
        cmake_args.append("-DWITH_QT=OFF")
        cmake_args.append("-DWITH_GTK=OFF")
        cmake_args.append("-DWITH_MSMF=OFF")
        cmake_args.append("-DWITH_OBSENSOR=OFF")

    if sys.platform.startswith("linux") and not is64 and "bdist_wheel" in sys.argv:
        subprocess.check_call("patch -p0 < patches/patchOpenEXR", shell=True)

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
                fonts = []
                for file in os.listdir("/usr/share/fonts/dejavu"):
                    if file.endswith(".ttf"):
                        fonts.append((r"lib/qt/fonts/dejavu/%s\.ttf" % file.split(".")[0]))
                rearrange_cmake_output_data["cv2.qt.fonts"] = fonts
            if sys.platform == "darwin":
                rearrange_cmake_output_data["cv2.qt.plugins.platforms"] = [
                    (r"lib/qt/plugins/platforms/libqcocoa\.dylib")
                ]
        if sys.platform.startswith("linux"):
            cmake_args.append("-DWITH_V4L=ON")
            cmake_args.append("-DWITH_LAPACK=ON")
            cmake_args.append("-DENABLE_PRECOMPILED_HEADERS=OFF")

    # --- PATCH: Handle config file for free-threaded python ---
    class RearrangeCMakeOutput:
        _setuptools_wrap = None
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
            cls = self.__class__
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
            final_install_relpaths = []

            print("Copying files from CMake output")

            # PATCH: Write config file for free-threaded python
            with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts', '__init__.py'), 'r') as custom_init:
                custom_init_data = custom_init.read()

            config_major = sys.version_info[0]
            config_minor = sys.version_info[1]
            free_threaded = is_free_threaded_python()
            # Try config-3t.py for free-threaded python
            config_file_name = f"config-{config_major}{'t' if free_threaded else ''}.py"
            config_py = os.path.join(cmake_install_dir, 'python', 'cv2', config_file_name)
            if not os.path.exists(config_py):
                # Fallback to config-3.py
                config_py = os.path.join(cmake_install_dir, 'python', 'cv2', f"config-{config_major}.py")

            with open(config_py, 'w') as opencv_init_config:
                opencv_init_config.write(custom_init_data)

            if sys.version_info >= (3, 6):
                for p in install_relpaths:
                    if p.endswith(".pyi"):
                        target_rel_path = os.path.relpath(p, "python/cv2")
                        cls._setuptools_wrap._copy_file(
                            os.path.join(cmake_install_dir, p),
                            os.path.join(cmake_install_dir, "cv2", target_rel_path),
                            hide_listing=False,
                        )
                        final_install_relpaths.append(os.path.join("cv2", target_rel_path))

            del install_relpaths, fslash_install_relpaths

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
                cmake_source_dir="",
                _cmake_install_dir=cmake_install_reldir,
            )

    RearrangeCMakeOutput(
        rearrange_cmake_output_data, files_outside_package_dir, package_data.keys()
    )

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
    )

    print("OpenCV is raising funds to keep the library free for everyone, and we need the support of the entire community to do it. Donate to OpenCV on GitHub:\nhttps://github.com/sponsors/opencv\n")

def get_and_set_info(contrib, headless, rolling, ci_build):
    version = {}
    here = os.path.abspath(os.path.dirname(__file__))
    version_file = os.path.join(here, "cv2", "version.py")
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

class EmptyListWithLength(list):
    def __len__(self):
        return 1

if __name__ == "__main__":
    main()