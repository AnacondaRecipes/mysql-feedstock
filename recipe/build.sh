#!/bin/bash

set -ex

# rpcgen is provided by the rpcsvc-proto package, which is available
# in BUILD_PREFIX/bin and should work correctly with the Conda cpp.

declare -a _xtra_cmake_args
if [[ $target_platform == osx-64 ]]; then
    export CXXFLAGS="${CXXFLAGS:-} -D_LIBCPP_DISABLE_AVAILABILITY=1"
fi

cmake -S$SRC_DIR -Bbuild -GNinja ${CMAKE_ARGS} \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCOMPILATION_COMMENT=Anaconda \
  -DCMAKE_FIND_FRAMEWORK=LAST \
  -DOPENSSL_ROOT_DIR=$PREFIX \
  -DPKG_CONFIG_EXECUTABLE=${BUILD_PREFIX}/bin/pkg-config \
  -DWITH_UNIT_TESTS=OFF \
  -DWITH_ZLIB=system \
  -DWITH_ZSTD=system \
  -DWITH_LZ4=system \
  -DWITH_ICU=system \
  -DWITH_EDITLINE=system \
  -DWITH_PROTOBUF=system \
  -DWITH_KERBEROS=none \
  -DWITH_FIDO=none \
  -DWITH_SASL=none \
  -DPROTOBUF_INCLUDE_DIR=${PREFIX}/include \
  -DDEFAULT_CHARSET=utf8 \
  -DDEFAULT_COLLATION=utf8_general_ci \
  -DINSTALL_INCLUDEDIR=include/mysql \
  -DINSTALL_MANDIR=share/man \
  -DINSTALL_DOCDIR=share/doc/mysql \
  -DINSTALL_DOCREADMEDIR=mysql \
  -DINSTALL_INFODIR=share/info \
  -DCMAKE_INSTALL_PREFIX=$PREFIX \
  -DINSTALL_MYSQLSHAREDIR=share/mysql \
  -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
  -DWITH_AUTHENTICATION_CLIENT_PLUGINS=ON \
  -DWITH_BUILD_ID=OFF \
  "${_xtra_cmake_args[@]}"

export NINJA_STATUS="[%f+%r/%t] "

cmake --build build
