//
//  FileDropTarget.swift
//  Adwaita
//
//  Created by desbeers on 21.08.2026.
//

import CAdw
import Foundation

/// File Drop handler for Widgets.
enum FileDropTarget {

    /// Handle dropped files.
    /// - Parameters:
    ///   - pointer: Pointer to the dropped files.
    ///   - filter: Optional filter for the dropped files.
    /// - Returns: An URL array with the dropped files.
    static func handleDroppedFiles(_ pointer: UnsafeRawPointer, filter: FileDialogFilter?) -> [URL] {
        var result: [URL] = []

        let gValue = pointer.assumingMemoryBound(to: GValue.self)
        guard let gPointer = g_value_get_boxed(gValue) else {
            return []
        }
        let fileList = OpaquePointer(gPointer)
        var files = gdk_file_list_get_files(fileList)
        while let current = files {
            if let data = current.pointee.data,
                let uri = g_file_get_uri(OpaquePointer(data)),
                let url = URL(string: String(cString: uri)),
                filterDroppedFile(data, url: url, filter: filter) {
                // Accept this drop
                result.append(url)
            }
            files = current.pointee.next
        }
        return result
    }

    /// Filter a dropped file URL.
    /// - Parameters:
    ///   - gpointer: The pointer to the file.
    ///   - url: The URL of the file.
    ///   - filter: The optional filter.
    /// - Returns: True if the file is valid or if no filter is supplied; else false
    static func filterDroppedFile(_ gpointer: gpointer, url: URL, filter: FileDialogFilter?) -> Bool {
        guard let filter else {
            return true
        }
        switch filter {
        case let .extensions(extensions, _):
            return extensions.contains(url.pathExtension)
        case let .mimeType(mimeType, _):
            var result = ""
            let info = g_file_query_info(
                OpaquePointer(gpointer),
                "standard::content-type",
                .FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                nil,
                nil
            )
            let contentType = g_file_info_get_attribute_string(info, "standard::content-type")
            if let contentType {
                result = String(cString: contentType)
            }
            g_object_unref(info?.cast())
            if mimeType.hasSuffix("/*") {
                return result.hasPrefix(String(mimeType.dropLast()))
            }
            return result == mimeType
        }
    }

}
