//
//  Enumerations.swift
//  Adwaita
//
//  Created by david-swift on 21.01.24.
//

import CAdw

/// The alignment for a widget.
public typealias Alignment = Align

/// The visibility of a scroll bar.
public typealias ScrollbarVisibility = PolicyType

/// A transition for a stack.
public typealias Transition = StackTransitionType

/// Length units.
extension LengthUnit {

    /// Pixels.
    public static var pixels: Self { .px }
    /// Points, changes with text scale factor.
    public static var points: Self { .pt }
    /// Scale independent pixels, changes with text scale factor.
    public static var scaleIndependentPixels: Self { .sp }

}

extension ScrollbarVisibility {

    /// The scrollbar is always visible. The view size is independent of the content.
    public static var alwaysVisible: Self { .always }

}

extension WrapPolicy {

    /// The minimum size wrap policy ``WrapPolicy/minimum`̀`.
    public static var minimumSize: Self { .minimum }
    /// The natural size wrap policy ``WrapPolicy/natural``.
    public static var naturalSize: Self { .natural }

}
