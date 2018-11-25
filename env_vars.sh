if [ -n "$IS_OSX" ]; then
    :
else
    yum clean metadata
fi