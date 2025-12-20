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
LIBHARFBUZZ_INC_DIR="${13}"
LIBHARFBUZZ_LIB_DIR="${14}"
LIBDECREPIT_LIB_DIR="${15}"
CUDA_INC_DIR="${16}"
CUDA_LIB_DIR="${17}"
INSTALL_DIR="${18}"
CONFIGURE_FLAGS="${19}"
LDFLAGS="${20}"
YASM="${21}"
GENERATOR_SUFFIX="${22}"

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
CONFIG_OPTS="${CONFIG_OPTS} --extra-ldflags=-L${LIBX264_LIB_DIR} --extra-ldflags=-L${LIBDECREPIT_LIB_DIR}"
CONFIG_OPTS="${CONFIG_OPTS} --prefix=${INSTALL_DIR}"

echo "CC: ${CC}"
echo "OS: ${OS}"
echo "ARCH: ${ARCH}"
echo "AR: ${AR}"
echo "LIBX264_INC_DIR: ${LIBX264_INC_DIR}"
echo "LIBX264_LIB_DIR: ${LIBX264_LIB_DIR}"
echo "LIBFREETYPE_INC_DIR: ${LIBFREETYPE_INC_DIR}"
echo "LIBFREETYPE_LIB_DIR: ${LIBFREETYPE_LIB_DIR}"
echo "LIBHARFBUZZ_INC_DIR: ${LIBHARFBUZZ_INC_DIR}"
echo "LIBHARFBUZZ_LIB_DIR: ${LIBHARFBUZZ_LIB_DIR}"
echo "LIBDECREPIT_LIB_DIR: ${LIBDECREPIT_LIB_DIR}"
echo "CUDA_INC_DIR: ${CUDA_INC_DIR}"
echo "CUDA_LIB_DIR: ${CUDA_LIB_DIR}"
echo "INSTALL_DIR: ${INSTALL_DIR}"
echo "CONFIGURE_FLAGS: ${CONFIGURE_FLAGS}"
echo "LDFLAGS: ${LDFLAGS}"
echo "YASM: ${YASM}"
echo "GENERATOR_SUFFIX: ${GENERATOR_SUFFIX}"

if [ "$OS" = "android" ] ; then
  CONFIG_OPTS="${CONFIG_OPTS} --host=armv7"
  export AR
  export RANLIB
  export CPP="${CC} -E"
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
  CONFIG_OPTS="${CONFIG_OPTS} --disable-cross_compile --cc=${CC_SH} --enable-pic"
fi

CFLAGS="${CFLAGS} -I${LIBX264_INC_DIR} -I${LIBX264_LIB_DIR}"  # LIBX264_LIB_DIR for x264_config.h
CFLAGS="${CFLAGS} -I${LIBFREETYPE_INC_DIR} -I${LIBHARFBUZZ_INC_DIR}"
export CFLAGS
export LDFLAGS

# Configure checks existence of libx264 using pkg-config
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${LIBX264_LIB_DIR}"
# as well as libfreetype
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${LIBFREETYPE_LIB_DIR}"
# as well as libharfbuzz
PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${LIBHARFBUZZ_LIB_DIR}"
export PKG_CONFIG_PATH

echo "CFLAGS: ${CFLAGS}"
echo "CONFIG_OPTS: ${CONFIG_OPTS}"
echo "PKG_CONFIG_PATH: ${PKG_CONFIG_PATH}"

${DIR}/configure ${CONFIG_OPTS} --arch=${ARCH}

