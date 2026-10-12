//
//  ToolbarDemo.swift
//  Adwaita
//
//  Created by david-swift on 03.01.24.
//

// swiftlint:disable missing_docs

import Adwaita
import CAdw

struct ViewSwitcherDemo: View {

    var app: AdwaitaApp

    var view: Body {
        VStack {
            Button("View Demo") {
                app.showWindow("switcher-demo")
            }
            .suggested()
            .pill()
            .frame(maxWidth: 100)
        }
    }

    struct WindowContent: View {

        @State private var selection: ViewSwitcherView = .albums
        @State private var bottom = false

        var view: Body {
            VStack {
                Text(selection.title)
                    .padding()
            }
            .valign(.center)
            .topToolbar {
                if bottom {
                    HeaderBar
                        .empty()
                } else {
                    toolbar(bottom: false)
                }
            }
            .bottomToolbar(visible: bottom) {
                toolbar(bottom: true)
            }
            .naturalWidth(matches: .init { !bottom } set: { bottom = !$0 })
        }

        func toolbar(bottom: Bool) -> AnyView {
            HeaderBar(titleButtons: !bottom) { } end: { }
                .headerBarTitle {
                    ViewSwitcher(selectedElement: $selection)
                        .wideDesign(!bottom)
                }
        }

    }

    enum ViewSwitcherView: String, ViewSwitcherOption, CaseIterable {

        case albums
        case artists
        case songs
        case playlists

        var title: String {
            rawValue.capitalized
        }

        var icon: Icon {
            .default(icon: {
                switch self {
                case .albums:
                    return .mediaOpticalCdAudio
                case .artists:
                    return .avatarDefault
                case .songs:
                    return .emblemMusic
                case .playlists:
                    return .viewList
                }
            }())
        }

    }

}

// swiftlint:enable missing_docs
