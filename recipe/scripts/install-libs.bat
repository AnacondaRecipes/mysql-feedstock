cmake -DCOMPONENT=SharedLibraries -P %SRC_DIR%/build/cmake_install.cmake
move %LIBRARY_LIB%\*.dll %LIBRARY_BIN%\
