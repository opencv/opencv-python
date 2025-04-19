# Import the default setuptools PEP 517 build backend under a custom alias
# This allows us to extend or override its functionality where needed
from setuptools import build_meta as _orig

# Re-use the default implementations for standard PEP 517 hook methods
prepare_metadata_for_build_wheel = _orig.prepare_metadata_for_build_wheel
build_wheel = _orig.build_wheel
build_sdist = _orig.build_sdist
get_requires_for_build_sdist = _orig.get_requires_for_build_sdist

# Override the `get_requires_for_build_wheel` function to add dynamic dependency logic
def get_requires_for_build_wheel(config_settings=None):
    from packaging import version
    from skbuild.exceptions import SKBuildError
    from skbuild.cmaker import get_cmake_version
    packages = _orig.get_requires_for_build_wheel(config_settings)
    # check if system cmake can be used if present
    # if not, append cmake PyPI distribution to required packages
    # scikit-build>=0.18 itself requires cmake 3.5+
    # Define the minimum required version of CMake (needed by scikit-build>=0.18)
    min_version = "3.5"
    try:
        if version.parse(get_cmake_version().split("-")[0]) < version.parse(min_version):
            packages.append(f'cmake>={min_version}')
    except SKBuildError:
        packages.append(f'cmake>={min_version}')

# Return the final list of required packages for building the wheel
    return packages
