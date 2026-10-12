//
//  ViewData.swift
//  Adwaita
//
//  Created by david-swift on 13.08.26.
//

import Meta

extension WidgetData {

    /// The orientation in the view's context.
    var orientationContext: Orientation? {
        get { fields[.orientation] as? Orientation }
        set { fields[.orientation] = newValue }
    }

    /// The spacing in the view's context.
    var spacingContext: Int? {
        get { fields[.spacing] as? Int }
        set { fields[.spacing] = newValue }
    }

    /// Receive the orientation from the widget's data and the context.
    /// - Property data: The orientation data in the widget.
    /// - Returns: The orientation.
    public func getOrientation(data: Orientation?) -> Orientation {
        data ?? orientationContext ?? .vertical
    }

    /// Receive the spacing from the widget's data and the context.
    /// - Property data: The spacing data in the widget.
    /// - Returns: The spacing.
    public func getSpacing(data: Int?) -> Int {
        data ?? spacingContext ?? 0
    }

    /// Set the widget data's orientation.
    /// - Property data: The orientation data in the widget.
    /// - Returns: The orientation.
    public func orientation(_ orientation: Orientation?) -> WidgetData {
        var newSelf = self
        newSelf.orientationContext = orientation
        return  newSelf
    }

    /// Set the widget data's spacing.
    /// - Property data: The spacing data in the widget.
    /// - Returns: The spacing.
    public func spacing(_ spacing: Int?) -> WidgetData {
        var newSelf = self
        newSelf.spacingContext = spacing
        return  newSelf
    }

}
