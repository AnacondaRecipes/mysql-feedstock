#!/bin/bash

set -ex

cmake -DCOMPONENT=SharedLibraries -P ${SRC_DIR}/build/cmake_install.cmake
