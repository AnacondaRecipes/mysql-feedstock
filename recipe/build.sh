#!/bin/bash
set -x

# Make rpcgen use C Pre Processor provided by the Conda ecosystem. The
# rpcgen binary assumes that the corresponding binary is always 'cpp'.
_rpcgen_hack_dir=$SRC_DIR/rpcgen_hack

if [[ "${target_platform}" == *"linux"* ]]; then
    # absl_log_internal_message is missing on linux
    export CXXFLAGS="${CXXFLAGS} -labsl_log_internal_message"
    
    ## We don't have a conda package for rpcgen, but it is present in the
    ## compiler sysroot on Linux. However, the value of PT_INTERP is not
    ## convenient for executing it. ('lib' instead of 'lib64')
    _target_sysroot=$(realpath $($CXX --print-sysroot))
    _target_rpcgen_bin=${_target_sysroot}/usr/bin/rpcgen
    _target_interpreter=$(realpath ${_target_sysroot}/$(patchelf --print-interpreter ${_target_rpcgen_bin}))
    if [[ "${target_platform}" == "linux-s390x" ]]; then
        # FIXME! the interpreter symlink found in the s390x sysroot is broken
        # (literal 'ld64.so*' instead of 'ld64.so.1').
        # this workaround assumes that there's exactly one ld-*.so library in the
        # sysroot. if more than one or no library matches the glob, build will fail.
        _target_interpreter=$(dirname "${_target_interpreter}")/ld-*.so
    fi
    _target_libdir=${_target_sysroot}/$(dirname ${_target_interpreter} | rev | cut -d '/' -f 1 | rev)

    ## Generate a wrapper which will use the interpreter provided in the
    ## compiler sysroot to exec rpcgen and also provide the appropriate
    ## /path/to/dir containing the C Pre Processor (cpp) binary.
    mkdir -p $_rpcgen_hack_dir/bin
    cat <<EOF > ${_rpcgen_hack_dir}/bin/rpcgen
#!/bin/bash
${_target_interpreter} --library-path ${_target_libdir} ${_target_rpcgen_bin} -Y ${_rpcgen_hack_dir}/bin \$@
EOF
    ln -s $(readlink -f ${CPP}) ${_rpcgen_hack_dir}/bin/cpp
    chmod +x ${_rpcgen_hack_dir}/bin/{rpcgen,cpp}

elif [[ "${target_platform}" == *"osx"* ]]; then
    # Remove explicitly ' -std=c++17' because CXXFLAGS already has -std=c++20 on osx platforms,
    # c++20 is already by default from v8.3.0, see https://github.com/mysql/mysql-server/blob/mysql-8.4.3/cmake/build_configurations/compiler_options.cmake#L65C39-L65C49
    export CXXFLAGS="${CXXFLAGS/ -std=c++17/}"
    ## Unlink GNU Compilers, Clang doesn't provide a separate binary
    ## for pre processing. So we trick rpcgen to use our Clang instead.
    mkdir -p $_rpcgen_hack_dir/bin
    cat <<EOF > ${_rpcgen_hack_dir}/bin/rpcgen
#!/bin/bash
rpcgen -Y ${_rpcgen_hack_dir}/bin \$@
EOF
    ln -s $BUILD_PREFIX/bin/$(basename ${CC}) ${_rpcgen_hack_dir}/bin/cpp
    chmod +x ${_rpcgen_hack_dir}/bin/{rpcgen,cpp}
fi

declare -a _xtra_cmake_args
if [[ $target_platform == osx-64 ]]; then
    _xtra_cmake_args+=(-DWITH_ROUTER=OFF)
    export CXXFLAGS="${CXXFLAGS:-} -D_LIBCPP_DISABLE_AVAILABILITY=1"
fi
if [[ $target_platform == linux-aarch64 ]]; then
    _xtra_cmake_args+=(-DWITH_BUILD_ID=OFF)
fi

cmake -S$SRC_DIR -Bbuild -GNinja ${CMAKE_ARGS} \
  -DCMAKE_CXX_STANDARD=20 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${_rpcgen_hack_dir};$PREFIX" \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DINSTALL_INCLUDEDIR=include/mysql \
  -DINSTALL_MANDIR=share/man \
  -DINSTALL_DOCDIR=share/doc/mysql \
  -DINSTALL_DOCREADMEDIR=mysql \
  -DINSTALL_INFODIR=share/info \
  -DINSTALL_MYSQLSHAREDIR=share/mysql \
  -DINSTALL_MYSQLTESTDIR= \
  -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
  -DCMAKE_FIND_FRAMEWORK=LAST \
  -DADD_GDB_INDEX=OFF \
  -DMYSQL_MAINTAINER_MODE=OFF \
  -DWITH_SYSTEM_LIBS=ON \
  -DWITH_AUTHENTICATION_LDAP=OFF \
  -DWITH_UNIT_TESTS=OFF \
  -DDEFAULT_CHARSET=utf8 \
  -DDEFAULT_COLLATION=utf8_general_ci \
  -DCOMPILATION_COMMENT=Anaconda \
  "${_xtra_cmake_args[@]}"

cmake --build build --target install

ln -s ${PREFIX}/mysql/support-files/mysql.server ${PREFIX}/bin/mysql.server
