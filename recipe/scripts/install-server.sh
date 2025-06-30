#!/bin/bash

set -ex

cmake -DCOMPONENT=Server -P ${SRC_DIR}/build/cmake_install.cmake
cmake -DCOMPONENT=Server_Scripts -P ${SRC_DIR}/build/cmake_install.cmake
ln -s ${PREFIX}/mysql/support-files/mysql.server ${PREFIX}/bin/mysql.server
