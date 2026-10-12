//
//  HeaderBar+.swift
//  Adwaita
//
//  Created by david-swift on 21.01.23.
//

extension HeaderBar {

    /// Initialize a header bar.
    /// - Parameters:
    ///   - titleButtons: Whether the title buttons (e.g. close button) are visible.
    ///   - start: The start content.
    ///   - end: The end content.
    public init(
        titleButtons: Bool = true,
        @ViewBuilder start: @escaping () -> Body,
        @ViewBuilder end: @escaping () -> Body
    ) {
        self.init()
        self = self.showStartTitleButtons(titleButtons).showEndTitleButtons(titleButtons)
        self = self.start(start).end(end)
    }

    /// Initialize a header bar.
    /// - Parameters:
    ///   - fullscreen: The binding to the fullscreen state.
    ///   - start: The start content.
    ///   - end: The end content.
    ///
    /// When the window is fullscreen, the title buttons will be hidden
    /// and an 'exit fullscreen' button will be shown instead.
    public init(
        fullscreen: Binding<Bool>,
        @ViewBuilder start: @escaping () -> Body,
        @ViewBuilder end: @escaping () -> Body
    ) {
        let isFullscreen = fullscreen.wrappedValue
        self.init()
        self = self.showStartTitleButtons(!isFullscreen).showEndTitleButtons(!isFullscreen)
        self = self.start(start).end {
            if isFullscreen {
                Button(icon: .default(icon: .viewRestore)) {
                    fullscreen.wrappedValue = false
                }
            }
            end()
        }
    }

    /// Initialize an empty header bar.
    /// - Returns: The header bar.
    public static func empty() -> Self {
        .init(start: { }, end: { })
    }

    /// Initialize a header bar with only views at the start.
    /// - Parameter start: The views.
    /// - Returns: The header bar.
    public static func start(@ViewBuilder start: @escaping () -> Body) -> Self {
        .init(start: start) { }
    }

    /// Initialize a header bar with only views at the end.
    /// - Parameter start: The views.
    /// - Returns: The header bar.
    public static func end(@ViewBuilder end: @escaping () -> Body) -> Self {
        .init(start: { }, end: end)
    }

    /// Set the title widget for the header bar.
    /// - Parameter view: The widget in the header bar.
    /// - Returns: The header bar.
    public func headerBarTitle(@ViewBuilder view: @escaping () -> Body) -> Self {
        titleWidget(view)
    }

}
