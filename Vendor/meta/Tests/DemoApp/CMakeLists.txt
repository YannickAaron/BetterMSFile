add_executable(DemoApp
        DemoApp.swift
)

target_compile_options(DemoApp PUBLIC
        -parse-as-library
)

target_link_libraries(DemoApp PRIVATE SampleBackends)

set_target_properties(DemoApp PROPERTIES
        Swift_LANGUAGE_VERSION 5
)
