//
//  AboutDialog.swift
//  Adwaita
//
//  Created by david-swift on 21.03.24.
//

import CAdw
import Foundation

/// The about dialog widget.
struct AboutDialog: AdwaitaWidget {

    /// Whether the dialog is visible.
    @Binding var visible: Bool
    /// The wrapped view.
    var child: AnyView

    /// The app's name.
    var appName: String?
    /// The developer's name.
    var developer: String?
    /// The app version.
    var version: String?
    /// The app icon.
    var icon: Icon?
    /// Details.
    var details: [AboutDialogDetail]?
    /// Links.
    var links: [AboutDialogLink]?

    /// The ID for the dialog's storage.
    let dialogID = "dialog"

    /// Initialize the about dialog wrapper.
    /// - Parameters:
    ///     - visible: The visibility.
    ///     - child: The child view.
    ///     - appName: The app's name.
    ///     - developer: The developer's name.
    ///     - version: The version.
    ///     - icon: The icon.
    ///     - details: Details of the app.
    ///     - links: Links.
    init(
        visible: Binding<Bool>,
        child: AnyView,
        appName: String? = nil,
        developer: String? = nil,
        version: String? = nil,
        icon: Icon? = nil,
        details: [AboutDialogDetail]? = nil,
        links: [AboutDialogLink]? = nil
    ) {
        self._visible = visible
        self.child = child
        self.appName = appName
        self.developer = developer
        self.version = version
        self.icon = icon
        self.details = details
        self.links = links
    }

    /// The view storage.
    /// - Parameters:
    ///     - modifiers: Modify views before being updated.
    ///     - type: The view render data type.
    /// - Returns: The view storage.
    func container<Data>(data: WidgetData, type: Data.Type) -> ViewStorage where Data: ViewRenderData {
        child.storage(data: data, type: type)
    }

    /// Update the stored content.
    /// - Parameters:
    ///     - storage: The storage to update.
    ///     - modifiers: Modify views before being updated
    ///     - updateProperties: Whether to update the view's properties.
    ///     - type: The view render data type.
    func update<Data>(
        _ storage: ViewStorage,
        data: WidgetData,
        updateProperties: Bool,
        type: Data.Type
    ) where Data: ViewRenderData {
        child.updateStorage(storage, data: data, updateProperties: updateProperties, type: type)
        guard updateProperties else {
            return
        }
        if visible {
            if storage.content[dialogID]?.first == nil {
                createDialog(storage: storage)
                adw_dialog_present(
                    storage.content[dialogID]?.first?.opaquePointer?.cast(),
                    storage.opaquePointer?.cast()
                )
            }
            let dialog = storage.content[dialogID]?.first?.opaquePointer
            if let appName {
                adw_about_dialog_set_application_name(dialog, appName)
            }
            if let developer {
                adw_about_dialog_set_developer_name(dialog, developer)
            }
            if let version {
                adw_about_dialog_set_version(dialog, version)
            }
            if let icon {
                adw_about_dialog_set_application_icon(dialog, icon.string)
            }
            if let links {
                setLinks(dialog, links: links)
            }
            if let details {
                setDetails(dialog, details: details)
            }
            adw_dialog_set_content_height(dialog?.cast(), -1)
        } else {
            if storage.content[dialogID]?.first != nil {
                let dialog = storage.content[dialogID]?.first?.opaquePointer
                adw_dialog_close(dialog?.cast())
                storage.content[dialogID] = []
            }
        }
    }

    /// Assign the links to the dialog.
    /// - Parameters:
    ///     - dialog: The about dialog.
    ///     - links: The links.
    func setLinks(_ dialog: OpaquePointer?, links: [AboutDialogLink]) {
        for link in links {
            switch link {
            case let .website(url):
                adw_about_dialog_set_website(dialog, url?.absoluteString)
            case let .support(url):
                adw_about_dialog_set_support_url(dialog, url?.absoluteString)
            case let .issues(url):
                adw_about_dialog_set_issue_url(dialog, url?.absoluteString)
            case let .add(url, title):
                adw_about_dialog_add_link(dialog, title, url?.absoluteString)
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity
    /// Assign the details to the dialog.
    /// - Parameters:
    ///     - dialog: The about dialog.
    ///     - details: The details.
    func setDetails(_ dialog: OpaquePointer?, details: [AboutDialogDetail]) {
        for detail in details {
            switch detail {
            case let .comment(text):
                adw_about_dialog_set_comments(dialog, text)
            case let .copyright(text):
                adw_about_dialog_set_copyright(dialog, text)
            case let .developers(names):
                names.withCArray { names in
                    adw_about_dialog_set_developers(dialog, names)
                }
            case let .designers(names):
                names.withCArray { names in
                    adw_about_dialog_set_designers(dialog, names)
                }
            case let .artists(names):
                names.withCArray { names in
                    adw_about_dialog_set_artists(dialog, names)
                }
            case let .documenters(names):
                names.withCArray { names in
                    adw_about_dialog_set_documenters(dialog, names)
                }
            case let .translators(names):
                adw_about_dialog_set_translator_credits(dialog, names.joined(separator: "\n"))
            case let .creditSection(items, label):
                items.withCArray { items in
                    adw_about_dialog_add_credit_section(dialog, label, items)
                }
            case let .acknowledgementSection(items, label):
                items.withCArray { items in
                    adw_about_dialog_add_acknowledgement_section(dialog, label, items)
                }
            case let .licenseType(type):
                adw_about_dialog_set_license_type(dialog, type.gtkValue)
            case let .license(text):
                adw_about_dialog_set_license(dialog, text)
            case let .debugInfo(text):
                adw_about_dialog_set_debug_info(dialog, text)
            case let .debugInfoFilename(text):
                adw_about_dialog_set_debug_info_filename(dialog, text)
            case let .releaseNotes(text):
                adw_about_dialog_set_release_notes(dialog, text)
            case let .releaseNotesVersion(text):
                adw_about_dialog_set_release_notes_version(dialog, text)
            }
        }
    }
    // swiftlint:enable cyclomatic_complexity

    /// Create a new instance of the dialog.
    /// - Parameter storage: The wrapped view's storage.
    func createDialog(storage: ViewStorage) {
        let pointer = adw_about_dialog_new()
        let dialog = ViewStorage(pointer?.opaque())
        storage.content[dialogID] = [dialog]
        dialog.connectSignal(name: "closed", type: .noArgs) {
            storage.content[dialogID] = []
            if visible {
                visible = false
            }
        }
    }

}

/// Links to show in the About Dialog.
public enum AboutDialogLink {

    /// The application website.
    case website(_: URL?)
    /// Support questions.
    case support(_: URL?)
    /// Issue reporting.
    case issues(_: URL?)
    /// Any link with a title.
    case add(URL?, title: String)

}

/// Details to show in the About Dialog.
public enum AboutDialogDetail {

    /// A comment about the application.
    /// - Note: The comment will be shown on the Details page, above links.
    case comment(_: String)
    /// The copyright information.
    /// - Note: The copyright information will be displayed on the Legal page, above the application license.
    case copyright(_: String)
    /// The list of developers of the application.
    /// - Note: It will be displayed on the Credits page.
    case developers(_: [String])
    /// The list of designers of the application.
    /// - Note: It will be displayed on the Credits page.
    case designers(_: [String])
    /// The list of artists of the application.
    /// - Note: It will be displayed on the Credits page.
    case artists(_: [String])
    /// The list of documenters of the application.
    /// - Note: It will be displayed on the Credits page.
    case documenters(_: [String])
    ///  The list of translators of the application.
    /// - Note: It will be displayed on the Credits page.
    case translators(_: [String])
    /// An extra section to the Credits page.
    /// - Note: Extra sections are displayed below the standard categories.
    case creditSection(_: [String], label: String)
    /// Add a section to the acknowledgements page
    case acknowledgementSection(_: [String], label: String)
    /// The license type from a list of known licenses.
    /// - Note: The license description will be displayed on the Legal page, below the copyright information.
    case licenseType(_: License)
    /// A custom text for the license if it can’t be set from the list of known licenses.
    /// - Note: The license text will be displayed on the Legal page, below the copyright information.
    case license(_: String)
    /// The debug information for the application.
    /// - Note: Debug information will be shown on the Troubleshooting page.
    case debugInfo(_: String)
    /// The debug information filename.
    /// - Note: It will be used as the suggested filename when saving debug information to a file.
    case debugInfoFilename(_: String)
    /// The release notes of the application.
    /// - Note: Release notes are displayed on the the What’s New page.
    case releaseNotes(_: String)
    /// Set the version described by the application’s release notes.
    ///
    /// If not set, AdwAboutDialog:version will be used instead.
    ///
    /// For example, an application with the current version 2.0.2 might want to keep
    /// the release notes from 2.0.0, and set the release notes version accordingly.
    case releaseNotesVersion(_: String)

}
