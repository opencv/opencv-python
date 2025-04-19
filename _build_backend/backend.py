"""
Custom build backend for setuptools + scikit-build-based Python packages.
Ensures CMake >= 3.5 is available for building C/C++ extensions.
"""

from setuptools import build_meta as _orig

# Pass-through functions from the original setuptools backend
prepare_metadata_for_build_wheel = _orig.prepare_metadata_for_build_wheel
build_wheel = _orig.build_wheel
build_sdist = _orig.build_sdist
get_requires_for_build_sdist = _orig.get_requires_for_build_sdist

def get_requires_for_build_wheel(config_settings=None):
    """
    Returns a list of additional build-time dependencies required to build a wheel.

    This custom version checks if the system has an appropriate version of CMake
    (>= 3.5), which is required by scikit-build. If not present or outdated, it
    appends 'cmake>=3.5' to the required packages list.

    Args:
        config_settings (dict, optional): Configuration settings (unused).

    Returns:
        List[str]: List of required build dependencies.
    """
    from packaging import version
    from skbuild.exceptions import SKBuildError
    from skbuild.cmaker import get_cmake_version

    # Get default requirements
    packages = list(_orig.get_requires_for_build_wheel(config_settings))

    # Define minimum version required
    min_version = "3.5"

    try:
        cmake_ver = get_cmake_version().split("-")[0]
        if version.parse(cmake_ver) < version.parse(min_version):
            packages.append(f'cmake>={min_version}')
    except (SKBuildError, OSError, ValueError) as e:
        # Catch broader exceptions in case of system misconfigurations
        packages.append(f'cmake>={min_version}')

    return packages