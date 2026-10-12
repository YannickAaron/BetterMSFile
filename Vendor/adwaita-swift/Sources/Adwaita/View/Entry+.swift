//
//  Entry+.swift
//  Adwaita
//
//  Created by david-swift on 19.04.25.
//

extension Entry {

    /// Initialize an entry.
    /// - Parameters:
    ///     - placeholder: The placeholder text.
    ///     - text: The value.
    public init(_ placeholder: String, text: Binding<String>) {
        self.init()
        self = self
            .text(text)
            .placeholderText(placeholder)
    }

}
