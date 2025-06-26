import Foundation

/// Prints the authorization status of a file in the cache
@objc(SNTCommandCheckCache)
class SNTCommandCheckCache: SNTCommand {
    override var shortHelp: String {
        return "Prints the authorization status of a file in the cache."
    }
    
    override var longHelp: String {
        return """
        Prints the authorization status of a file in the cache.
        
        IMPORTANT: This command is intended for development purposes only.
        """
    }
    
    override var requiresRoot: Bool {
        // This command is technically an information leak. Require root so that
        // normal users don't gain additional insights.
        return true
    }
    
    override var requiresDaemonConn: Bool {
        return true
    }
    
    var isHidden: Bool {
        return true
    }
    
    override func run(with arguments: [String]) async throws {
        guard let filePath = arguments.first else {
            printError("No file path provided")
            throw CommandError.invalidArguments
        }
        
        let vnodeID = vnodeIDForFile(filePath)
        
        guard let daemon = daemonInterface() else {
            throw CommandError.xpcConnectionFailed
        }
        
        let action = await withCheckedContinuation { (continuation: CheckedContinuation<SNTAction, Never>) in
            daemon.checkCache(forVnodeID: vnodeID) { action in
                continuation.resume(returning: action)
            }
        }
        
        switch action {
        case .respondAllow:
            print("File exists in [allowlist] cache")
        case .respondDeny:
            print("File exists in [blocklist] cache")
        case .respondAllowCompiler:
            print("File exists in [allowlist compiler] cache")
        case .unset:
            print("File does not exist in cache")
        }
    }
    
    private func vnodeIDForFile(_ path: String) -> SantaVnode {
        var statInfo = stat()
        let result = stat(path, &statInfo)
        
        if result == 0 {
            return SantaVnode(fsid: statInfo.st_dev, fileid: statInfo.st_ino)
        } else {
            // Return empty vnode on error
            return SantaVnode(fsid: 0, fileid: 0)
        }
    }
}

// MARK: - Placeholder Types

struct SantaVnode {
    let fsid: dev_t
    let fileid: ino_t
}

enum SNTAction: Int {
    case unset = 0
    case respondAllow = 1
    case respondDeny = 2
    case respondAllowCompiler = 3
}

extension SNTDaemonControlXPC {
    func checkCache(forVnodeID vnodeID: SantaVnode, withReply reply: @escaping (SNTAction) -> Void) {
        // Placeholder
        reply(.unset)
    }
}