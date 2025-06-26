import Foundation

/// Flush the authorization caches
@objc(SNTCommandFlushCache)
class SNTCommandFlushCache: SNTCommand {
    override var shortHelp: String {
        return "Flush the authorization caches"
    }
    
    override var longHelp: String {
        return """
        Flushes the authorization caches.
        
        IMPORTANT: This command is intended for development purposes only.
        """
    }
    
    override var requiresRoot: Bool {
        return true
    }
    
    override var requiresDaemonConn: Bool {
        return true
    }
    
    var isHidden: Bool {
        return true
    }
    
    override func run(with arguments: [String]) async throws {
        guard let daemon = daemonInterface() else {
            throw CommandError.xpcConnectionFailed
        }
        
        let success = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            daemon.flushCache { success in
                continuation.resume(returning: success)
            }
        }
        
        if success {
            print("Cache flush requested")
        } else {
            printError("Cache flush failed")
            throw CommandError.invalidOperation
        }
    }
}

// MARK: - XPC Extensions

extension SNTDaemonControlXPC {
    func flushCache(_ reply: @escaping (Bool) -> Void) {
        // Placeholder
        reply(true)
    }
}