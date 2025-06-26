import Foundation

/// Bridge to Objective-C XPC protocols
/// This file provides Swift-compatible interfaces for the XPC protocols

// Re-export the actual protocols from Objective-C
@_exported import class Source.common.SNTXPCControlInterface
@_exported import class Source.common.SNTXPCUnprivilegedControlInterface

// Add any Swift-specific extensions or helpers here
extension SNTXPCControlInterface {
    /// Configure a connection for santactl
    static func configuredConnection() -> NSXPCConnection? {
        // This will use the actual implementation from Objective-C
        return SNTXPCControlInterface.configuredConnection()
    }
}