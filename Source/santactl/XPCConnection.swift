import Foundation

// Helper for stderr output
extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

var standardError = FileHandle.standardError

/// Swift wrapper for XPC connections to the Santa daemon
public class XPCConnection {
    private var molConnection: MOLXPCConnection?
    private var xpcConnection: NSXPCConnection? {
        return molConnection?.value(forKey: "currentConnection") as? NSXPCConnection
    }
    
    /// Create a connection to the Santa daemon
    static func createDaemonConnection() -> XPCConnection? {
        let connection = XPCConnection()
        
        // Use SNTXPCControlInterface to create configured connection
        guard let molConn = SNTXPCControlInterface.configuredConnection() else {
            return nil
        }
        
        connection.molConnection = molConn
        
        // Set up invalidation handler
        molConn.invalidationHandler = {
            print("Connection to Santa daemon was invalidated", to: &standardError)
        }
        
        // Resume the connection
        molConn.resume()
        
        return connection
    }
    
    /// Get the remote object proxy for daemon control
    func daemonControlProxy() -> SNTDaemonControlXPC? {
        guard let conn = xpcConnection else { return nil }
        
        let proxy = conn.remoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error.localizedDescription)", to: &standardError)
        }
        
        return proxy as? SNTDaemonControlXPC
    }
    
    /// Get the synchronous remote object proxy for daemon control
    func synchronousDaemonControlProxy() -> SNTDaemonControlXPC? {
        guard let conn = xpcConnection else { return nil }
        
        let proxy = conn.synchronousRemoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error.localizedDescription)", to: &standardError)
        }
        
        return proxy as? SNTDaemonControlXPC
    }
    
    /// Get the remote object proxy for unprivileged daemon control
    func unprivilegedDaemonControlProxy() -> SNTUnprivilegedDaemonControlXPC? {
        guard let conn = xpcConnection else { return nil }
        
        let proxy = conn.remoteObjectProxyWithErrorHandler { error in
            print("XPC error: \(error.localizedDescription)", to: &standardError)
        }
        
        return proxy as? SNTUnprivilegedDaemonControlXPC
    }
    
    /// Invalidate the connection
    func invalidate() {
        molConnection?.invalidate()
    }
}

// Extensions to make the Objective-C protocols work better in Swift
extension SNTDaemonControlXPC {
    /// Swift-friendly wrapper for databaseRuleCounts
    func getRuleCounts() async -> RuleCounts {
        await withCheckedContinuation { continuation in
            self.databaseRuleCounts { counts in
                var ruleCounts = RuleCounts()
                ruleCounts.binary = counts["binary"]?.int64Value ?? 0
                ruleCounts.certificate = counts["certificate"]?.int64Value ?? 0
                ruleCounts.compiler = counts["compiler"]?.int64Value ?? 0
                ruleCounts.transitive = counts["transitive"]?.int64Value ?? 0
                ruleCounts.teamID = counts["teamID"]?.int64Value ?? 0
                ruleCounts.signingID = counts["signingID"]?.int64Value ?? 0
                ruleCounts.cdhash = counts["cdhash"]?.int64Value ?? 0
                continuation.resume(returning: ruleCounts)
            }
        }
    }
}

// Bridge to Objective-C types
@objc class SNTXPCControlInterface: NSObject {
    @objc static func configuredConnection() -> MOLXPCConnection? {
        // This will be provided by the Objective-C implementation
        return nil
    }
}

@objc class MOLXPCConnection: NSObject {
    @objc var invalidationHandler: (() -> Void)?
    
    @objc func resume() {
        // Provided by Objective-C implementation
    }
    
    @objc func invalidate() {
        // Provided by Objective-C implementation
    }
    
    @objc func remoteObjectProxyWithErrorHandler(_ handler: @escaping (Error) -> Void) -> Any? {
        // Provided by Objective-C implementation
        return nil
    }
}