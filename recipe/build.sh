#!/bin/bash
set -x

# Apple names internal headers 'VERSION' ... sick ... and doesn't include it relative to their file ... sick ...
# so fix this by renaming those files for the sake of OSX 11 SDKs ...
mv ./VERSION VERSION_MSQL
mv ./rapid/plugin/group_replication/libmysqlgcs/VERSION ./rapid/plugin/group_replication/libmysqlgcs/VERSION_MSQL
mv ./libbinlogevents/VERSION ./libbinlogevents/VERSION_MSQL

# Make rpcgen use C Pre Processor provided by the Conda ecosystem. The
# rpcgen binary assumes that the corresponding binary is always 'cpp'.
_rpcgen_hack_dir=$SRC_DIR/rpcgen_hack

if [[ "${target_platform}" == *"linux"* ]]; then
    ## We don't have a conda package for rpcgen, but it is present in the
    ## compiler sysroot on Linux. However, the value of PT_INTERP is not
    ## convenient for executing it. ('lib' instead of 'lib64')
    _target_sysroot=$($CXX --print-sysroot)
    _target_rpcgen_bin=${_target_sysroot}/usr/bin/rpcgen
    _target_interpreter=${_target_sysroot}/$(patchelf --print-interpreter ${_target_rpcgen_bin})
    _target_libdir=${_target_sysroot}/$(dirname ${_target_interpreter})

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

export CXXFLAGS="${CXXFLAGS} -std=c++14"

cmake -S$SRC_DIR -Bbuild -GNinja ${CMAKE_ARGS} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="${_rpcgen_hack_dir};$PREFIX" \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DINSTALL_INCLUDEDIR=include/mysql \
  -DINSTALL_MANDIR=share/man \
  -DINSTALL_DOCDIR=share/doc/mysql \
  -DINSTALL_DOCREADMEDIR=mysql \
  -DINSTALL_INFODIR=share/info \
  -DINSTALL_MYSQLSHAREDIR=share/mysql \
  -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
  -DINSTALL_SCRIPTDIR=mysql/scripts \
  -DCMAKE_FIND_FRAMEWORK=LAST \
  -DCMAKE_VERBOSE_MAKEFILE=OFF \
  -DWITH_UNIT_TESTS=OFF \
  -DDEFAULT_CHARSET=utf8 \
  -DDEFAULT_COLLATION=utf8_general_ci \
  -DCOMPILATION_COMMENT=conda-forge \
  -DWITH_SSL=system \
  -DWITH_EDITLINE=system \
  -DDOWNLOAD_BOOST=0 -DWITH_BOOST=${SRC_DIR}/boost \
  -DINSTALL_INCLUDEDIR=include/mysql \
  -DINSTALL_MANDIR=share/man \
  -DINSTALL_DOCDIR=share/doc/mysql \
  -DINSTALL_DOCREADMEDIR=mysql \
  -DINSTALL_MYSQLSHAREDIR=share/mysql \
  -DINSTALL_SUPPORTFILESDIR=mysql/support-files \
  "${_xtra_cmake_args[@]}"

if [[ $target_platform == osx-arm64 ]]; then
    # Update the /path/to/xprotocol_plugin to the one built for the build platform
    sed -i.bak "s,\(--plugin=protoc-gen-yplg=\)[^ ]*,\1$SRC_DIR/build.codegen/runtime_output_directory/xprotocol_plugin,g" build/build.ninja
fi

cmake --build build --target install

ln -s ${PREFIX}/mysql/support-files/mysql.server ${PREFIX}/bin/mysql.server

