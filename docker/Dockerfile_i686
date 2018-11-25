FROM quay.io/pypa/manylinux1_i686:latest

RUN curl -O -L https://download.qt.io/archive/qt/4.8/4.8.7/qt-everywhere-opensource-src-4.8.7.tar.gz && \
	tar -xf qt-everywhere-opensource-src-4.8.7.tar.gz && \
	cd qt-everywhere* && \
	./configure -prefix /opt/Qt4.8.7 -release -opensource -confirm-license && \
	gmake -j5 && \
	gmake install && \
	cd .. && \
	rm -rf qt-everywhere-opensource-src-4.8.7 && \
	rm qt-everywhere-opensource-src-4.8.7.tar.gz

ENV QTDIR /opt/Qt4.8.7
ENV PATH "$QTDIR/bin:$PATH"

RUN curl -O -L https://cmake.org/files/v3.9/cmake-3.9.0.tar.gz && \
	tar -zxf cmake-3.9.0.tar.gz && \
	cd cmake-3.9.0 && \
	yum -y install curl-devel zlib-devel && \
	./configure --system-curl && \
	make && \
	make install && \
	cd .. && \
	rm -rf cmake-3.9.0*

RUN yum install autoconf automake bzip2 cmake freetype-devel gcc gcc-c++ libtool make mercurial pkgconfig zlib-devel -y && \
	yum remove nasm -y && \
	mkdir ~/ffmpeg_sources && \
	cd ~/ffmpeg_sources && \
	curl -O -L http://www.nasm.us/pub/nasm/releasebuilds/2.13.02/nasm-2.13.02.tar.bz2 && \
	tar xjvf nasm-2.13.02.tar.bz2 && cd nasm-2.13.02 && ./autogen.sh && \
	./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
	make -j4 && \
	make install && \
	cd ~/ffmpeg_sources && \
	curl -O -L http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz && \
	tar xzvf yasm-1.3.0.tar.gz && \
	cd yasm-1.3.0 && \
	./configure --prefix="$HOME/ffmpeg_build" --bindir="$HOME/bin" && \
	make -j4 && \
	make install && \
	cd ~/ffmpeg_sources && \
	git clone --depth 1 https://chromium.googlesource.com/webm/libvpx.git && \
	cd libvpx && \
	./configure --prefix="$HOME/ffmpeg_build" --disable-examples --disable-unit-tests --enable-vp9-highbitdepth --as=yasm --enable-pic --enable-shared && \
	make -j4 && \
	make install && \
	cd ~/ffmpeg_sources && \
	curl -O -L https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
	tar xjvf ffmpeg-snapshot.tar.bz2 && \
	cd ffmpeg && \
	PATH=~/bin:$PATH && \
	PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure --prefix="$HOME/ffmpeg_build" --extra-cflags="-I$HOME/ffmpeg_build/include" --extra-ldflags="-L$HOME/ffmpeg_build/lib" --enable-libvpx --enable-shared --enable-pic --bindir="$HOME/bin" && \
	make -j4 && \
	make install && \
	echo "/root/ffmpeg_build/lib/" >> /etc/ld.so.conf && \
	ldconfig && \
	rm -rf ~/ffmpeg_sources

ENV PKG_CONFIG_PATH /usr/local/lib/pkgconfig:/root/ffmpeg_build/lib/pkgconfig
ENV LDFLAGS -L/root/ffmpeg_build/lib

RUN mkdir libjpeg-turbo && \
	cd libjpeg-turbo && \
	export PATH=~/bin:$PATH && \
	curl -L https://kent.dl.sourceforge.net/project/libjpeg-turbo/1.5.3/libjpeg-turbo-1.5.3.tar.gz > libjpeg-turbo-1.5.3.tar.gz && \
	tar xzvf libjpeg-turbo-1.5.3.tar.gz && \
	cd libjpeg-turbo-1.5.3 && \
	export CFLAGS="-fPIC" && \
	export CXXFLAGS="-fPIC" && \
	autoreconf -fiv && \
	./configure --host=i686-pc-linux-gnu && \
	make && \
	make install && \
	cd ../../ && \
	rm -rf libjpeg-turbo

ENV JPEG_LIBRARY /opt/libjpeg-turbo/lib32/libjpeg.a
ENV JPEG_INCLUDE_DIR /opt/libjpeg-turbo/include

RUN curl -O https://raw.githubusercontent.com/torvalds/linux/v4.14/include/uapi/linux/videodev2.h && \
	curl -O https://raw.githubusercontent.com/torvalds/linux/v4.14/include/uapi/linux/v4l2-common.h && \
	curl -O https://raw.githubusercontent.com/torvalds/linux/v4.14/include/uapi/linux/v4l2-controls.h && \
	curl -O https://raw.githubusercontent.com/torvalds/linux/v4.14/include/linux/compiler.h && \
	mv videodev2.h v4l2-common.h v4l2-controls.h compiler.h /usr/include/linux

RUN yum clean all

ENV PATH "$HOME/bin:$PATH"
