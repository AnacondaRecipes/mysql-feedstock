#!/bin/bash

set -ex

cmake -DCOMPONENT=Development -P ${SRC_DIR}/build/cmake_install.cmake

if [[ "${target_platform}" == *"linux"* ]]; then
    sed -i 's,zlib,z,g' ${PREFIX}/bin/mysql_config
elif [[ "${target_platform}" == *"osx"* ]]; then
    sed -i '' -e 's,zlib,z,g' ${PREFIX}/bin/mysql_config
fi
