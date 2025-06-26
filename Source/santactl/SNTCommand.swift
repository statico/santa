import Foundation

/// Protocol that all santactl commands must implement
@objc(SNTCommandProtocol)
public protocol SNTCommandProtocol {
    /// Short description of the command
    var shortHelp: String { get }
    
    /// Long help text for the command
    var longHelp: String { get }
    
    /// Whether this command requires root privileges
    var requiresRoot: Bool { get }
    
    /// Whether this command requires a daemon connection
    var requiresDaemonConn: Bool { get }
    
    /// Initialize the command
    init()
    
    /// Run the command with the given arguments
    func run(with arguments: [String]) async throws
}

/// Base class for all santactl commands
@objc(SNTCommand)
open class SNTCommand: NSObject, SNTCommandProtocol {
    /// XPC connection to the daemon (set by controller if needed)
    public var daemonConnection: NSXPCConnection?
    
    /// Short description of the command
    open var shortHelp: String {
        return "No description available"
    }
    
    /// Long help text for the command
    open var longHelp: String {
        return shortHelp
    }
    
    /// Whether this command requires root privileges
    open var requiresRoot: Bool {
        return false
    }
    
    /// Whether this command requires a daemon connection
    open var requiresDaemonConn: Bool {
        return true
    }
    
    /// Required initializer
    public required override init() {
        super.init()
    }
    
    /// Run the command with the given arguments
    open func run(with arguments: [String]) async throws {
        fatalError("Subclasses must implement run(with:)")
    }
    
    /// Parse command-specific flags
    open func parseArguments(_ arguments: [String]) throws -> [String: Any] {
        var options: [String: Any] = [:]
        var remainingArgs: [String] = []
        
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            
            if arg.hasPrefix("--") {
                // Long option
                if arg.contains("=") {
                    let parts = arg.split(separator: "=", maxSplits: 1)
                    let key = String(parts[0].dropFirst(2))
                    let value: Any = parts.count > 1 ? String(parts[1]) : true
                    options[key] = value
                } else {
                    let key = String(arg.dropFirst(2))
                    // Check if next argument is a value
                    if i + 1 < arguments.count && !arguments[i + 1].hasPrefix("-") {
                        options[key] = arguments[i + 1]
                        i += 1
                    } else {
                        options[key] = true
                    }
                }
            } else if arg.hasPrefix("-") && arg.count > 1 {
                // Short option
                let key = String(arg.dropFirst())
                // Check if next argument is a value
                if i + 1 < arguments.count && !arguments[i + 1].hasPrefix("-") {
                    options[key] = arguments[i + 1]
                    i += 1
                } else {
                    options[key] = true
                }
            } else {
                // Not an option
                remainingArgs.append(arg)
            }
            
            i += 1
        }
        
        options["_remaining"] = remainingArgs
        return options
    }
    
    /// Print an error message
    public func printError(_ message: String) {
        // Print directly to stderr using FileHandle
        let errorMessage = "Error: \(message)\n"
        if let errorData = errorMessage.data(using: .utf8) {
            FileHandle.standardError.write(errorData)
        }
    }
    
    /// Get the daemon interface
    public func daemonInterface() -> SNTDaemonControlXPC? {
        guard let connection = daemonConnection else {
            return nil
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            self.printError("XPC error: \(error.localizedDescription)")
        }
        
        return proxy as? SNTDaemonControlXPC
    }
    
    /// Get the unprivileged daemon interface
    public func unprivilegedDaemonInterface() -> SNTUnprivilegedDaemonControlXPC? {
        guard let connection = daemonConnection else {
            return nil
        }
        
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            self.printError("XPC error: \(error.localizedDescription)")
        }
        
        return proxy as? SNTUnprivilegedDaemonControlXPC
    }
}

/// Protocol for daemon control XPC interface
@objc public protocol SNTDaemonControlXPC {
    // This will be populated with actual methods from SNTXPCControlInterface
    func databaseRuleCounts(reply: @escaping ([String: NSNumber]) -> Void)
    func clientMode(reply: @escaping (SNTClientMode) -> Void)
    func syncState(reply: @escaping ([String: Any]?) -> Void)
}

/// Protocol for unprivileged daemon control XPC interface  
@objc public protocol SNTUnprivilegedDaemonControlXPC {
    // This will be populated with actual methods from SNTXPCUnprivilegedControlInterface
    func staticRuleCounts(reply: @escaping ([String: NSNumber]) -> Void)
}

/// Client mode enum (placeholder - will use actual from SNTCommonEnums)
@objc public enum SNTClientMode: Int {
    case monitor = 0
    case lockdown = 1
}