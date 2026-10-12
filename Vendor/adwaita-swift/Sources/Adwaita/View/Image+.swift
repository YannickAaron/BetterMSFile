//
//  Image+.swift
//  Adwaita
//
//  Created by desbeers on 18.08.26.
//

import CAdw
import Foundation

extension Image {

    /// Init the image with an URL.
    /// - Parameter url: The URL of the image.
    public init(url: URL) {
        updateFunctions.append { storage, _, updateProperties in
            if updateProperties {
                guard url.path != storage.fields[.filePath] as? String else {
                    return
                }
                gtk_image_set_from_file(storage.opaquePointer, url.path)
                storage.fields[.filePath] = url.path
            }
        }
    }
}
