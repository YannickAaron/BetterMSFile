add_library(LevenshteinTransformations 
            Extensions/Array.swift
            Extensions/String.swift 
            AsyncFunctions.swift
            EditOperation.swift
            Functions.swift
            LevenshteinTransformations.swift
            Transformation.swift
)   

install(TARGETS LevenshteinTransformations
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
)