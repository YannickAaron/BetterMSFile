cmake_minimum_required(VERSION 3.29)
cmake_policy(SET CMP0157 NEW)

project(LevenshteinTransformations 
        LANGUAGES Swift)

set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(Sources)

if(CMAKE_PROJECT_NAME STREQUAL "LevenshteinTransformations")
    add_subdirectory(Tests)
endif()