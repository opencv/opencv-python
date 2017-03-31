pip install twine

if [[ $ENABLE_CONTRIB == 0 ]]; then
	echo "This is default build. Deployment will be done to to PyPI entry opencv-python."
else
	echo "This is contrib build. Deployment will be done to to PyPI entry opencv-contrib-python."
fi

if [ -n "$TRAVIS_TAG" ]; then
	twine upload -u ${USER} -p ${PASS} --skip-existing ${TRAVIS_BUILD_DIR}/wheelhouse/opencv*;
else
	echo "Tag not set, deployment skipped.";
fi