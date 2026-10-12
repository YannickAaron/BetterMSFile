add_executable(Tests 
        LevenshteinTransformationsTests.swift
)

target_compile_options(Tests PUBLIC 
        -parse-as-library
)   

target_link_libraries(Tests PRIVATE 
        LevenshteinTransformations
)