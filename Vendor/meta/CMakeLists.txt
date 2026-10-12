cmake_minimum_required(VERSION 3.29)
project(Meta LANGUAGES Swift)

if(POLICY CMP0157)
    cmake_policy(SET CMP0157 NEW)
endif()

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(Sources)
add_subdirectory(Tests)