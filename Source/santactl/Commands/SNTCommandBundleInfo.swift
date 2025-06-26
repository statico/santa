import Foundation

/// Searches a bundle for binaries
@objc(SNTCommandBundleInfo)
class SNTCommandBundleInfo: SNTCommand {
    override var shortHelp: String {
        return "Searches a bundle for binaries."
    }
    
    override var longHelp: String {
        return "Searches a bundle for binaries."
    }
    
    override var requiresRoot: Bool {
        return false
    }
    
    override var requiresDaemonConn: Bool {
        return false
    }
    
    override func run(with arguments: [String]) async throws {
        guard let bundlePath = arguments.first else {
            printError("No bundle path provided")
            throw CommandError.invalidArguments
        }
        
        // Create file info
        guard let fileInfo = SNTFileInfo(path: bundlePath) else {
            printError("Failed to create file info for path: \(bundlePath)")
            throw CommandError.invalidArguments
        }
        
        guard fileInfo.bundle != nil else {
            printError("Not a bundle")
            throw CommandError.invalidArguments
        }
        
        // Create stored event
        let storedEvent = SNTStoredEvent()
        storedEvent.fileBundlePath = fileInfo.bundlePath
        
        // Get bundle service connection
        guard let bundleConnection = SNTXPCBundleServiceInterface.configuredConnection() else {
            printError("Failed to create bundle service connection")
            throw CommandError.xpcConnectionFailed
        }
        
        bundleConnection.resume()
        
        // Hash bundle binaries
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<(hash: String, events: [SNTStoredEvent], time: UInt64), Never>) in
            if let proxy = bundleConnection.remoteObjectProxyWithErrorHandler({ error in
                print("XPC error: \(error.localizedDescription)", to: &standardError)
                continuation.resume(returning: (hash: "", events: [], time: 0))
            }) as? SNTBundleServiceXPC {
                proxy.hashBundleBinaries(for: storedEvent, listener: nil) { hash, events, time in
                    continuation.resume(returning: (hash: hash ?? "", 
                                                  events: events ?? [], 
                                                  time: time?.uint64Value ?? 0))
                }
            } else {
                continuation.resume(returning: (hash: "", events: [], time: 0))
            }
        }
        
        // Print results
        print("Hashing time: \(result.time) ms")
        print("\(result.events.count) events found")
        print("BundleHash: \(result.hash)")
        
        for event in result.events {
            if let bundleID = event.fileBundleID,
               let sha256 = event.fileSHA256,
               let path = event.filePath {
                print("BundleID: \(bundleID) \n\tSHA-256: \(sha256) \n\tPath: \(path)")
            }
        }
    }
}

// MARK: - Placeholder Types

@objc protocol SNTBundleServiceXPC {
    func hashBundleBinaries(for event: SNTStoredEvent, 
                           listener: NSXPCListenerEndpoint?, 
                           reply: @escaping (String?, [SNTStoredEvent]?, NSNumber?) -> Void)
}

@objc class SNTXPCBundleServiceInterface: NSObject {
    @objc static func configuredConnection() -> MOLXPCConnection? {
        // Placeholder - will be provided by Objective-C implementation
        return nil
    }
}

