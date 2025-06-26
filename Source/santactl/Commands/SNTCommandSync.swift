import Foundation
import os.log

/// Synchronizes Santa with a configured server
@objc(SNTCommandSync)
class SNTCommandSync: SNTCommand {
    private var enableDebugLogging = false
    private var logListener: NSXPCListener?
    private var logConnection: MOLXPCConnection?
    
    override var shortHelp: String {
        return "Synchronizes Santa with a configured server."
    }
    
    override var longHelp: String {
        return """
        If Santa is configured to synchronize with a server, this is the command used for syncing.
        
        Options:
          --clean: Perform a clean sync, erasing all existing non-transitive rules and
                   requesting a clean sync from the server.
          --clean-all: Perform a clean sync, erasing all existing rules and requesting a
                       clean sync from the server.
          --debug: Enable debug logging
        """
    }
    
    override var requiresRoot: Bool {
        return false
    }
    
    override var requiresDaemonConn: Bool {
        return false  // We talk directly with the syncservice
    }
    
    override func run(with arguments: [String]) async throws {
        // Ensure we have no privileges
        if !dropRootPrivileges() {
            printError("Failed to drop root privileges. Exiting.")
            throw CommandError.invalidOperation
        }
        
        // Check for sync URL configuration
        guard SNTConfigurator.shared.syncBaseURL != nil else {
            printError("Missing SyncBaseURL. Exiting.")
            throw CommandError.invalidOperation
        }
        
        // Configure sync service connection
        guard let syncConnection = SNTXPCSyncServiceInterface.configuredConnection() else {
            printError("Failed to create sync service connection")
            throw CommandError.xpcConnectionFailed
        }
        
        syncConnection.invalidationHandler = { [weak self] in
            self?.printError("Failed to connect to the sync service.")
            exit(1)
        }
        
        syncConnection.resume()
        
        // Set up log listener
        logListener = NSXPCListener.anonymous()
        guard let listener = logListener else {
            throw CommandError.xpcConnectionFailed
        }
        
        logConnection = MOLXPCConnection(initServerWithListener: listener)
        logConnection?.exportedObject = self
        logConnection?.unprivilegedInterface = NSXPCInterface(with: SNTSyncServiceLogReceiverXPC.self)
        logConnection?.resume()
        
        // Determine sync type
        var syncType = SNTSyncType.normal
        if arguments.contains("--clean-all") {
            syncType = .cleanAll
        } else if arguments.contains("--clean") {
            syncType = .clean
        }
        
        enableDebugLogging = arguments.contains("--debug")
        
        // Perform sync
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<SNTSyncStatusType, Never>) in
            if let proxy = syncConnection.remoteObjectProxyWithErrorHandler({ error in
                self.printError("XPC error: \(error.localizedDescription)")
                continuation.resume(returning: .internalError)
            }) as? SNTSyncServiceXPC {
                proxy.sync(withLogListener: listener.endpoint,
                          syncType: syncType) { statusRaw in
                    let status = SNTSyncStatusType(rawValue: Int(statusRaw)) ?? .internalError
                    if status == .tooManySyncsInProgress {
                        self.didReceiveLog("Too many syncs in progress, try again later.",
                                         with: .error)
                    }
                    continuation.resume(returning: status)
                }
            } else {
                continuation.resume(returning: .internalError)
            }
        }
        
        // Exit with the sync status
        exit(Int32(result.rawValue))
    }
    
    private func dropRootPrivileges() -> Bool {
        // If we're not root, nothing to drop
        if getuid() != 0 {
            return true
        }
        
        // Try to drop privileges
        // This is a simplified version - in production, would use SNTDropRootPrivs
        let realUID = getuid()
        let realGID = getgid()
        
        if setgid(realGID) != 0 || setuid(realUID) != 0 {
            return false
        }
        
        return true
    }
}

// MARK: - SNTSyncServiceLogReceiverXPC Protocol

extension SNTCommandSync: SNTSyncServiceLogReceiverXPC {
    func didReceiveLog(_ log: String, with logType: OSLogType) {
        if logType == .debug && !enableDebugLogging {
            return
        }
        print(log)
        fflush(stdout)
    }
}

// MARK: - Placeholder Types and Extensions

@objc protocol SNTSyncServiceLogReceiverXPC {
    @objc func didReceiveLog(_ log: String, with logType: OSLogType)
}

@objc protocol SNTSyncServiceXPC {
    @objc func postEvents(toSyncServer events: [SNTStoredEvent], fromBundle: Bool)
    @objc func postBundleEvent(toSyncServer event: SNTStoredEvent, reply: @escaping (Int) -> Void)
    @objc func pushNotificationStatus(_ reply: @escaping (Int) -> Void)
    @objc func exportTelemetryFile(_ fd: FileHandle, fileName: String, config: SNTExportConfiguration, reply: @escaping (Bool) -> Void)
    @objc func sync(withLogListener logListener: NSXPCListenerEndpoint, syncType: SNTSyncType, reply: @escaping (Int) -> Void)
    @objc func spindown()
    @objc func apnsTokenChanged()
    @objc func handleAPNSMessage(_ message: [String: Any])
}

@objc class SNTXPCSyncServiceInterface: NSObject {
    @objc static func configuredConnection() -> MOLXPCConnection? {
        // Placeholder - will be provided by Objective-C implementation
        return nil
    }
    
    @objc static func syncServiceInterface() -> NSXPCInterface {
        return NSXPCInterface(with: SNTSyncServiceXPC.self)
    }
    
    @objc static func serviceID() -> String {
        return "com.google.santa.syncservice"
    }
}

@objc class SNTStoredEvent: NSObject {
    @objc var fileBundlePath: String?
    @objc var fileBundleID: String?
    @objc var fileSHA256: String?
    @objc var filePath: String?
}

@objc class SNTExportConfiguration: NSObject {
    // Placeholder
}

enum SNTBundleEventAction: Int {
    case none = 0
    case download = 1
    case open = 2
}

enum SNTSyncStatusType: Int {
    case success = 0
    case internalError = 1
    case tooManySyncsInProgress = 2
    case commsError = 3
}

extension MOLXPCConnection {
    @objc convenience init?(initServerWithListener listener: NSXPCListener) {
        // Placeholder
        self.init()
    }
    
    @objc var unprivilegedInterface: NSXPCInterface? {
        get { nil }
        set { }
    }
    
    @objc var exportedObject: Any? {
        get { nil }
        set { }
    }
}