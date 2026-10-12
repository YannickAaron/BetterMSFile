//
//  Array.swift
//  LevenshteinTransformations
//
//  Created by david-swift on 01.01.24.
//

extension Array where Element: Equatable {

    /// Calculate the Levenshtein distance to another array.
    /// - Parameter target: The target array.
    /// - Returns: The Levenshtein distance.
    public func levenshteinDistance(to target: [Element]) -> Int {
        levenshteinDistance(to: target, id: \.self)
    }

    /// Get the transformations needed to transform the array into the target array.
    /// - Parameter target: The target array.
    /// - Returns: The transformations.
    public func getTransformations(to target: [Element]) -> [Transformation<Element>] {
        getTransformations(to: target, id: \.self)
    }

    /// Call every transformation step needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - functions: The transformation functions.
    public func transform(to target: [Element], functions: Functions<Element>) {
        transform(to: target, id: \.self, functions: functions)
    }

    /// Call every transformation step needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - functions: The transformation functions.
    public func transform(to target: [Element], functions: AsyncFunctions<Element>) async {
        await transform(to: target, id: \.self, functions: functions)
    }

}

extension Array where Element: Identifiable {

    /// Calculate the Levenshtein distance to another array.
    /// - Parameter target: The target array.
    /// - Returns: The Levenshtein distance.
    public func identifiableLevenshteinDistance(to target: [Element]) -> Int {
        identifiableGetTransformations(to: target).count
    }

    /// Get the transformations needed to transform the array into the target array.
    /// - Parameter target: The target array.
    /// - Returns: The transformations.
    public func identifiableGetTransformations(to target: [Element]) -> [Transformation<Element>] {
        LevenshteinTransformations.levenshteinTransformations(from: self, to: target)
    }

    /// Call every transformation step needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - functions: The transformation functions.
    public func identifiableTransform(to target: [Element], functions: Functions<Element>) {
        transform(to: target, id: \.id, functions: functions)
    }

    /// Call every transformation step needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - functions: The transformation functions.
    public func identifiableTransform(to target: [Element], functions: AsyncFunctions<Element>) async {
        await transform(to: target, id: \.id, functions: functions)
    }

}

extension Array {

    /// Calculate the Levenshtein distance to another array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - id: The identifier.
    /// - Returns: The Levenshtein distance.
    public func levenshteinDistance<Identifier>(
        to target: [Element],
        id: KeyPath<Element, Identifier>
    ) -> Int where Identifier: Equatable {
        getRawTransformations(to: target, id: id).count
    }

    /// Get the transformations needed to transform the array into the target array with the raw identifier data.
    /// - Parameters:
    ///     - target: The target array.
    ///     - id: The identifier.
    /// - Returns: The transformations applied to the identifier.
    public func getRawTransformations<Identifier>(
        to target: [Element],
        id: KeyPath<Element, Identifier>
    ) -> [Transformation<Identifier>] where Identifier: Equatable {
        let equatableSource = map { $0[keyPath: id] }
        let equatableTarget = target.map { $0[keyPath: id] }
        return LevenshteinTransformations.levenshteinTransformations(from: equatableSource, to: equatableTarget)
    }

    /// Get the transformations needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - id: The identifier.
    /// - Returns: The transformations.
    public func getTransformations<Identifier>(
        to target: [Element],
        id: KeyPath<Element, Identifier>
    ) -> [Transformation<Element>] where Identifier: Equatable {
        getRawTransformations(to: target, id: id)
            .compactMap { $0.convert { targetID in target.first { $0[keyPath: id] == targetID } } }
    }

    /// Call every transformation step needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - id: The identifier key path.
    ///     - functions: The transformation functions.
    public func transform<Identifier>(
        to target: [Element],
        id: KeyPath<Element, Identifier>,
        functions: Functions<Element>
    ) where Identifier: Equatable {
        var transformations = getTransformations(to: target, id: id)

        while !transformations.isEmpty {
            let transformation = transformations.removeFirst()
            transformation.transform(functions: functions, nextTransformations: &transformations)
        }
    }

    /// Call every transformation step needed to transform the array into the target array.
    /// - Parameters:
    ///     - target: The target array.
    ///     - id: The identifier key path.
    ///     - functions: The transformation functions.
    public func transform<Identifier>(
        to target: [Element],
        id: KeyPath<Element, Identifier>,
        functions: AsyncFunctions<Element>
    ) async where Identifier: Equatable {
        var transformations = getTransformations(to: target, id: id)

        while !transformations.isEmpty {
            let transformation = transformations.removeFirst()
            await transformation.transform(functions: functions, nextTransformations: &transformations)
        }
    }

}
