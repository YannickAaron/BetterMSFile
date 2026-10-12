//
//  Test.swift
//  meta-sqlite
//
//  Created by david-swift on 04.10.24.
//

import Meta
import MetaSQLite

/// The test function.
func main() {
    @State("test")
    var test = 0
    @State("other")
    var other = 3
    print(test)
    print(other)
    test = 1
    other = 0
}

main()
