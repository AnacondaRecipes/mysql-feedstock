#!/bin/bash

set -ex

# Make rpcgen use C Pre Processor provided by the Conda ecosystem. The
# rpcgen binary assumes that the corresponding binary is always 'cpp'.
_rpcgen_hack_dir=$SRC_DIR/rpcgen_hack

if [[ "${target_platform}" == *"linux"* ]]; then
    ## We don't have a conda package for rpcgen, but it is present in the
    ## compiler sysroot on Linux. However, the value of PT_INTERP is not
    ## convenient for executing it. ('lib' instead of 'lib64')
    _target_sysroot=$(${CXX_FOR_BUILD:-$CC} --print-sysroot)
    _target_rpcgen_bin=${_target_sysroot}/usr/bin/rpcgen
    _target_interpreter=${_target_sysroot}/$(patchelf --print-interpreter ${_target_rpcgen_bin})
    _target_libdir=$(dirname ${_target_interpreter})

    ## Generate a wrapper which will use the interpreter provided in the
    ## compiler sysroot to exec rpcgen and also provide the appropriate
    ## /path/to/dir containing the C Pre Processor (cpp) binary.
    mkdir -p $_rpcgen_hack_dir/bin
    cat <<EOF > ${_rpcgen_hack_dir}/bin/rpcgen
#!/bin/bash
${_target_interpreter} --library-path ${_target_libdir} ${_target_rpcgen_bin} -Y ${_rpcgen_hack_dir}/bin \$@
EOF
    ln -sf $(readlink -f ${CPP}) ${_rpcgen_hack_dir}/bin/cpp
    chmod +x ${_rpcgen_hack_dir}/bin/{rpcgen,cpp}

elif [[ "${target_platform}" == *"osx"* ]]; then
    ## Unlink GNU Compilers, Clang doesn't provide a separate binary
    ## for pre processing. So we trick rpcgen to use our Clang instead.
    mkdir -p $_rpcgen_hack_dir/bin
    cat <<EOF > ${_rpcgen_hack_dir}/bin/rpcgen
#!/bin/bash
rpcgen -Y ${_rpcgen_hack_dir}/bin \$@
EOF
    ln -sf $BUILD_PREFIX/bin/$(basename ${CC}) ${_rpcgen_hack_dir}/bin/cpp
    chmod +x ${_rpcgen_hack_dir}/bin/{rpcgen,cpp}
fi

declare -a _xtra_cmake_args
if [[ $target_platform == osx-64 ]]; then
    export CXXFLAGS="${CXXFLAGS:-} -D_LIBCPP_DISABLE_AVAILABILITY=1"
fi

cmake -S$SRC_DIR -Bbuild -GNinja ${CMAKE_ARGS} \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${_rpcgen_hack_dir};$PREFIX" \
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
