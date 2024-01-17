#!/bin/bash

PATH="$PATH:/usr/local/bin:/opt/homebrew/bin"

DIR="$1"
CC="$2"
CFLAGS="$3"
OS="$4"
ARCH="$5"
CCACHE="$6"
AR="$7"
RANLIB="$8"
LIBX264_INC_DIR="$9"
LIBX264_LIB_DIR="${10}"
LIBFREETYPE_INC_DIR="${11}"
LIBFREETYPE_LIB_DIR="${12}"
LIBRTMP_INC_DIR="${13}"
LIBRTMP_LIB_DIR="${14}"
LIBCRYPTO_LIB_DIR="${15}"
LIBSSL_LIB_DIR="${16}"
LIBDECREPIT_LIB_DIR="${17}"
CUDA_INC_DIR="${18}"
CUDA_LIB_DIR="${19}"
INSTALL_DIR="${20}"
CONFIGURE_FLAGS="${21}"
LDFLAGS="${22}"
YASM="${23}"

CONFIG_OPTS="\
--disable-iconv \
--disable-bzlib \
--disable-doc \
--disable-programs \
--enable-gpl \
--enable-nonfree \
--disable-lzma"
CONFIG_OPTS="${CONFIG_OPTS} ${CONFIGURE_FLAGS}"
CONFIG_OPTS="${CONFIG_OPTS} --disable-filters --enable-filter=fps --enable-filter=scale --enable-filter=pad --enable-filter=hstack --enable-filter=vstack --enable-filter=drawtext --enable-filter=overlay --enable-filter=crop"
#CONFIG_OPTS="${CONFIG_OPTS} --enable-hwaccel=nvenc --enable-nvenc"
CONFIG_OPTS="${CONFIG_OPTS} --extra-ldflags=-L${LIBX264_LIB_DIR} --extra-ldflags=-L${LIBSSL_LIB_DIR} --extra-ldflags=-L${LIBCRYPTO_LIB_DIR} --extra-ldflags=-L${LIBDECREPIT_LIB_DIR}"
CONFIG_OPTS="${CONFIG_OPTS} --prefix=${INSTALL_DIR}"

echo "CC: ${CC}"
echo "OS: ${OS}"
echo "ARCH: ${ARCH}"
echo "AR: ${AR}"
echo "LIBX264_INC_DIR: ${LIBX264_INC_DIR}"
echo "LIBX264_LIB_DIR: ${LIBX264_LIB_DIR}"
echo "LIBFREETYPE_INC_DIR: ${LIBFREETYPE_INC_DIR}"
echo "LIBFREETYPE_LIB_DIR: ${LIBFREETYPE_LIB_DIR}"
echo "LIBRTMP_INC_DIR: ${LIBRTMP_INC_DIR}"
echo "LIBRTMP_LIB_DIR: ${LIBRTMP_LIB_DIR}"
echo "LIBCRYPTO_LIB_DIR: ${LIBCRYPTO_LIB_DIR}"
echo "LIBSSL_LIB_DIR: ${LIBSSL_LIB_DIR}"
echo "LIBDECREPIT_LIB_DIR: ${LIBDECREPIT_LIB_DIR}"

if [ "$OS" = "android" ] ; then
  CONFIG_OPTS="${CONFIG_OPTS} --host=armv7"
  export AR
  export RANLIB
  export CPP="${CC} -E -D__STDC_CONSTANT_MACROS"
  export CPPFLAGS=${CFLAGS}
#elif [ "x$OS" = "xosx" ] ; then
  #OS=darwin12
  #CONFIG_OPTS="$CONFIG_OPTS --arch=x86_64 --x86asmexe=${YASM}"
  #CFLAGS="${CFLAGS} -arch x86_64"
  #LDFLAGS="${LDFLAGS} -arch x86_64"
elif [ "x$OS" = "xios" ] ; then
  OS=darwin
  if [ "x$ARCH" = "xi386" -o "x$ARCH" = "xx86_64" ] ; then
    SDK="iphonesimulator"
    OS=darwin12
  else
    SDK="iphoneos"
    CONFIG_OPTS="${CONFIG_OPTS} --host=arm-apple-darwin"
  fi
  CC="xcrun -sdk ${SDK} clang -arch ${ARCH}"
  if [ "x$CCACHE" != "x" ]; then
    CC="$CCACHE $CC"
  fi
elif [ "x$OS" = "xlinux" ] ; then
  # configure takes CC as -cc option, but it can be only one word.
  # so we use intermediate script to run ccache
  CC_SH="${LIBX264_LIB_DIR}/ccache_cc.sh"
  echo ${CC} \$* > ${CC_SH}
  chmod 755 ${CC_SH}
  CONFIG_OPTS="${CONFIG_OPTS} --disable-cross_compile --cc=${CC_SH} --enable-pic --extra-ldflags=-lpng"
fi

CFLAGS="${CFLAGS} -I${LIBX264_INC_DIR} -I${LIBX264_LIB_DIR} -I${LIBRTMP_INC_DIR}"  # LIBX264_LIB_DIR for x264_config.h
CFLAGS="${CFLAGS} -I${LIBFREETYPE_INC_DIR}"
export CFLAGS
export LDFLAGS

# Configure checks existence of libx264 and librtmp using pkg-config
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${LIBX264_LIB_DIR}:${LIBRTMP_LIB_DIR}/pkgconfig"
# as well as libfreetype
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${LIBFREETYPE_LIB_DIR}"
export PKG_CONFIG_PATH

echo "CFLAGS: ${CFLAGS}"
echo "CONFIG_OPTS: ${CONFIG_OPTS}"
echo "PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"

${DIR}/configure ${CONFIG_OPTS}

