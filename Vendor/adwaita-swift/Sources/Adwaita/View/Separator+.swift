//
//  Separator+.swift
//  Adwaita
//
//  Created by desbeers on 06.08.26.
//

extension Separator {

    /// Make a separator appear invisible and act as whitespace. .
    /// - Parameter active: Whether the style is currently applied.
    /// - Returns: A view.
    public func spacer(_ active: Bool = true) -> AnyView {
        style("spacer", active: active)
    }

}
