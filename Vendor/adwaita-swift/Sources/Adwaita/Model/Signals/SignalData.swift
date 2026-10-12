//
//  SignalData.swift
//  Adwaita
//
//  Created by david-swift on 31.07.24.
//

import CAdw

/// Data to pass to signal handlers.
public class SignalData {

    /// The closure.
    public var closure: ([Any?]) -> Any?
    /// Destroy the class.
    public var selfDestruction: (() -> Void)?

    /// Initialize the signal data.
    /// - Parameters:
    ///     - closure: The signal's closure.
    ///     - destroy: The self destruction.
    public convenience init(closure: @escaping () -> Any?, destroy: (() -> Void)? = nil) {
        self.init(closure: { _ in closure() }, destroy: destroy)
    }

    /// Initialize the signal data.
    /// - Parameters:
    ///     - closure: The signal's closure.
    ///     - destroy: The self destruction.
    public convenience init(closure: @escaping () -> Void, destroy: (() -> Void)? = nil) {
        self.init(closure: { _ in closure(); return nil }, destroy: destroy)
    }

    /// Initialize the signal data.
    /// - Parameters:
    ///     - closure: The signal's closure.
    ///     - destroy: The self destruction.
    public init(closure: @escaping ([Any]) -> Any?, destroy: (() -> Void)? = nil) {
        self.closure = closure
        self.selfDestruction = destroy
    }

    //// The type of the signal handler.
    public enum HandlerType {

        /// void (*, gpointer)
        case noArgs
        /// void (*, *, gpointer)
        case oneArg
        /// void (*, *, *, gpointer)
        case twoArgs

        /// void (*, double, double, gpointer)
        case doubleDouble
        /// void (*, *, double, double, gpointer)
        case pointerDoubleDouble
        /// void (*, guint, gpointer)
        case guint
        /// void (*, gpointer, gint, gchar*, gpointer)
        case pointerIntPointer

        /// gboolean (*, gpointer)
        case noArgsReturnsBool

        /// The closure as a C handler.
        var handler: @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Void {
            { _, data in
                _ = Self.cast(data).closure([])
            }
        }

        /// The closure as a C handler with three parameters.
        var threeParamsHandler: @convention(c) (
            UnsafeMutableRawPointer,
            UnsafeRawPointer?,
            UnsafeMutableRawPointer
        ) -> Void {
            { _, arg1, data in
                _ = Self.cast(data).closure([arg1])
            }
        }

        /// The closure as a C handler with four parameters.
        var fourParamsHandler: @convention(c) (
            UnsafeMutableRawPointer,
            UnsafeRawPointer?,
            UnsafeRawPointer?,
            UnsafeMutableRawPointer
        ) -> Void {
            { _, arg1, arg2, data in
                _ = Self.cast(data).closure([arg1, arg2])
            }
        }

        /// The closure as a C handler with five parameters.
        var fiveParamsHandler: @convention(c) (
            UnsafeMutableRawPointer,
            UnsafeRawPointer?,
            Double,
            Double,
            UnsafeMutableRawPointer
        ) -> Void {
            { _, arg1, arg2, arg3, data in
                _ = Self.cast(data).closure([arg1, arg2, arg3])
            }
        }

        /// The handler for guint.
        var guintHandler: @convention(c) (
            UnsafeMutableRawPointer,
            UInt32,
            UnsafeMutableRawPointer
        ) -> Void {
            { _, arg1, data in
                _ = Self.cast(data).closure([arg1])
            }
        }

        /// The handler for pointerIntPointer.
        var pointerIntPointerHandler: @convention(c) (
            UnsafeMutableRawPointer,
            UnsafeMutableRawPointer?,
            Int32,
            UnsafeMutableRawPointer?,
            UnsafeMutableRawPointer
        ) -> Void {
            { _, pointer, int, string, data in
                _ = Self.cast(data).closure([pointer, int, string])
            }
        }

        /// The handler for doubleDouble.
        var doubleDoubleHandler: @convention(c) (
            UnsafeMutableRawPointer,
            Double,
            Double,
            UnsafeMutableRawPointer
        ) -> Void {
            { _, arg1, arg2, data in
                _ = Self.cast(data).closure([arg1, arg2])
            }
        }

        /// The closure as a C handler with a return value.
        var boolHandler: @convention(c) (UnsafeMutableRawPointer, UnsafeMutableRawPointer) -> Bool {
            { _, data in
                let data = unsafeBitCast(data, to: SignalData.self)
                return data.closure([]) as? Bool ?? false
            }
        }

        /// The GCallback.
        var callback: GCallback {
            switch self {
            case .noArgs:
                unsafeBitCast(handler, to: GCallback.self)
            case .oneArg:
                unsafeBitCast(threeParamsHandler, to: GCallback.self)
            case .twoArgs:
                unsafeBitCast(fourParamsHandler, to: GCallback.self)
            case .doubleDouble:
                unsafeBitCast(doubleDoubleHandler, to: GCallback.self)
            case .pointerDoubleDouble:
                unsafeBitCast(fiveParamsHandler, to: GCallback.self)
            case .guint:
                unsafeBitCast(guintHandler, to: GCallback.self)
            case .pointerIntPointer:
                unsafeBitCast(pointerIntPointerHandler, to: GCallback.self)
            case .noArgsReturnsBool:
                unsafeBitCast(boolHandler, to: GCallback.self)
            }
        }

        /// Cast the pointer to the signal data.
        /// - Returns: The signal data.
        static func cast(_ data: UnsafeMutableRawPointer) -> SignalData {
            unsafeBitCast(data, to: SignalData.self)
        }

    }

    /// Connect the signal data to a signal.
    /// - Parameters:
    ///     - pointer: The pointer to the object which holds the signal.
    ///     - signal: The signal's name.
    ///     - type: The handler type.
    public func connect(
        pointer: UnsafeMutableRawPointer?,
        signal: String,
        type: HandlerType
    ) {
        let destroy: GClosureNotify = { data, _ in
            guard let data else {
                return
            }
            let signalData: SignalData = Unmanaged.fromOpaque(data).takeUnretainedValue()
            signalData.selfDestruction?()
        }
        g_signal_connect_data(
            pointer,
            signal,
            type.callback,
            Unmanaged.passUnretained(self).toOpaque().cast(),
            destroy,
            GConnectFlags(rawValue: 1)
        )
    }

}
