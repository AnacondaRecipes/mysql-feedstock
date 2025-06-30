#!/bin/bash

set -ex

cmake -DCOMPONENT=Client -P ${SRC_DIR}/build/cmake_install.cmake
