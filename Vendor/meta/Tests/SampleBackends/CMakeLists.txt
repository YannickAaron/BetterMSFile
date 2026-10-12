add_library(SampleBackends
        Backend1.swift
        Backend2.swift
)

target_link_libraries(SampleBackends
        PRIVATE Meta
)

set_target_properties(SampleBackends PROPERTIES
        Swift_LANGUAGE_VERSION 5
)