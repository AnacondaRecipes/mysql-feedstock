#!/bin/bash

set -ex

cmake -DCOMPONENT=Router -P ${SRC_DIR}/build/cmake_install.cmake
