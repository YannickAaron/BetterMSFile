//
//  PictureDemo.swift
//  Adwaita
//
//  Created by david-swift on 21.04.24.
//

// swiftlint:disable missing_docs

import Adwaita
import Foundation

struct PictureDemo: View {

    @State private var fileDialog = Signal()
    @State private var url: URL?
    @State private var showToast = Signal()
    var app: AdwaitaApp
    var window: AdwaitaWindow
    var view: Body {
        Box {
            if let url {
                Picture(url: url)
            } else {
                StatusPage(
                    "Drop Area",
                    icon: .default(icon: .folderPictures)
                )
                .compact()
            }
        }
        .fileDropTarget(
            filter: .mimeType("image/*", name: "Drop an image here"),
        ) { urls in
            handleDrop(urls)
        }
        Button("Open") {
            fileDialog.signal()
        }
        .fileDropTarget(
            filter: .mimeType("image/*")
        ) { urls in
            handleDrop(urls)
        }
        .halign(.center)
        .valign(.center)
        .pill()
        .suggested()
        .padding()
        .toast("This is not an image", signal: $showToast)
        .fileImporter(
            open: $fileDialog,
            initialFolder: FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first,
            filters: [
                .extensions(["jpg", "jpeg"], name: "JPG Images"),
                .mimeType("image/*", name: "All Images")
            ],
            title: "Pick an Image",
            acceptLabel: "Open Image"
        ) { url in
            self.url = url
        }
    }

    private func handleDrop(_ urls: [URL]?) {
        if let urls, let dropped = urls.first {
            url = dropped
        } else {
            showToast.signal()
        }
    }

}

// swiftlint:enable missing_docs
