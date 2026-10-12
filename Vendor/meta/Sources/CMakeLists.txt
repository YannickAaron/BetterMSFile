file(GLOB META_SOURCES
        "Model/Data Flow/*.swift"

        "Model/Extensions/*.swift"

        "Model/User Interface/App/*.swift"
        "Model/User Interface/Scene/*.swift"
        "Model/User Interface/View/Properties/*.swift"
        "Model/User Interface/View/*.swift"

        "View/*.swift"
)

add_library(Meta ${META_SOURCES})

target_compile_options(Meta PUBLIC -enable-testing)

set_target_properties(Meta PROPERTIES
        Swift_LANGUAGE_VERSION 5
)

install(TARGETS Meta
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
)