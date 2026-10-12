//
//  Picture+.swift
//  Adwaita
//
//  Created by david-swift on 21.04.24.
//

import CAdw
import Foundation

extension Picture {

    /// Init the picture with an URL.
    /// - Parameter url: The URL of the picture.
    public init(url: URL) {
        updateFunctions.append { storage, _, updateProperties in
            if updateProperties {
                guard url.path != storage.fields[.filePath] as? String else {
                    return
                }
                gtk_picture_set_filename(storage.opaquePointer, url.path)
                storage.fields[.filePath] = url.path
            }
        }
    }

    /// Init the picture with Foundation's `Data`.
    /// - Parameter data: The data.
    public init(data: Data?) {
        updateFunctions.append { storage, _, updateProperties in
            if updateProperties {
                let pointer = storage.opaquePointer
                guard let data else {
                    if storage.fields[.data] != nil {
                        g_object_unref(gtk_picture_get_paintable(pointer)?.cast())
                        gtk_picture_set_paintable(pointer, gdk_paintable_new_empty(0, 0))
                        storage.fields[.data] = nil
                    }
                    return
                }
                guard data != storage.fields[.data] as? Data else {
                    return
                }
                let bytes = data.withUnsafeBytes { ptr in
                    g_bytes_new(ptr.baseAddress, .init(data.count))
                }
                let texture = gdk_texture_new_from_bytes(bytes, nil)
                g_bytes_unref(bytes)
                if let paintable = gtk_picture_get_paintable(pointer) {
                    g_object_unref(paintable.cast())
                }
                gtk_picture_set_paintable(pointer, texture)
                storage.fields[.data] = data
            }
        }
    }

}
