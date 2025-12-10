from setuptools import build_meta as _orig

prepare_metadata_for_build_wheel = _orig.prepare_metadata_for_build_wheel
build_wheel = _orig.build_wheel
build_sdist = _orig.build_sdist
get_requires_for_build_sdist = _orig.get_requires_for_build_sdist

def get_requires_for_build_wheel(config_settings=None):
    from packaging import version
    from skbuild.exceptions import SKBuildError
    from skbuild.cmaker import get_cmake_version
    packages = _orig.get_requires_for_build_wheel(config_settings)
    # check if system cmake can be used if present
    # if not, append cmake PyPI distribution to required packages
    # scikit-build>=0.18 itself requires cmake 3.5+
    min_version = "3.5"
    try:
        if version.parse(get_cmake_version().split("-")[0]) < version.parse(min_version):
            packages.append(f'cmake>={min_version}')
    except SKBuildError:
        packages.append(f'cmake>={min_version}')

    return packages
