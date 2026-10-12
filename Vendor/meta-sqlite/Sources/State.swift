//
//  State.swift
//  meta-sqlite
//
//  Created by david-swift on 04.10.24.
//

import Foundation
import Meta
import SQLite

extension State where Value: Codable {

    /// Initialize a property being remembered between launches of the app.
    /// - Parameters:
    ///     - wrappedValue: The wrapped value, used as an initial value if no stored value is found.
    ///     - stateID: The identifier for the stored value.
    ///     - forceUpdates: Whether to force update all available views when the property gets modified.
    ///     - blockUpdates: Whether to block all changes from updating the view.
    ///
    /// Define a custom path for storing the data with ``DatabaseInformation/setPath(_:)``.
    public init(
        wrappedValue: @autoclosure @escaping () -> Value,
        _ stateID: String,
        forceUpdates: Bool = false,
        blockUpdates: Bool = false
    ) {
        self.init(
            wrappedValue: {
                let query = DatabaseInformation.table
                        .filter(DatabaseInformation.id == stateID)
                        .limit(1)
                var data: Data?
                guard let rows = try? DatabaseInformation.connection?.prepare(query) else {
                    return wrappedValue()
                }
                for row in rows {
                    data = row[DatabaseInformation.data]
                }
                guard let data else {
                    return wrappedValue()
                }
                let value = try? JSONDecoder().decode(Value.self, from: data)
                return value ?? wrappedValue()
            },
            writeValue: { value in
                if let data = try? JSONEncoder().encode(value) {
                    _ = try? DatabaseInformation.connection?.run(
                        DatabaseInformation.table.insert(
                            or: .replace,
                            DatabaseInformation.id <- stateID,
                            DatabaseInformation.data <- data
                        )
                    )
                }
            },
            forceUpdates: forceUpdates,
            blockUpdates: blockUpdates
        )
    }

}

/// Information about the database.
public enum DatabaseInformation {

    /// The path.
    static var path = "./database.sqlite"
    /// The table.
    static let table = Table("data")
    /// The ID field.
    static let id = SQLite.Expression<String>("id")
    /// The data field.
    static let data = SQLite.Expression<Data>("data")
    /// The SQLite connection.
    private static var privateConnection: Connection?

    /// The SQLite connection.
    static var connection: Connection? {
        if let privateConnection {
            return privateConnection
        }
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let connection = try? Connection(path)
        privateConnection = connection
        _ = try? connection?.run(table.create { table in
            table.column(id, primaryKey: true)
            table.column(data)
        })
        return connection
    }

    /// Set the path to the SQLite file.
    /// - Parameter path: The path.
    ///
    /// Call this function before accessing any state values (when setting up the app storage).
    public static func setPath(_ path: String) {
        self.path = path
    }

}
