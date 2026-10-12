//
//  Symbol.swift
//  Adwaita
//
//  Created by Marquis Kurt on 23.10.25.
//

/// A view that display a symbolic image.
public typealias Symbol = Image

extension Symbol {

    /// Initialize a symbolic image view.
    /// - Parameter icon: The icon to display in the view.
    public init(icon: Icon) {
        self.init()
        self.iconName = icon.string
    }
}
