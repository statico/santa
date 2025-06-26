import Foundation

// Placeholder types that will be replaced with actual implementations
// These are temporary to allow the Swift code to compile

// MARK: - Configuration

@objc class SNTConfigurator: NSObject {
    @objc static let shared = SNTConfigurator()
    
    @objc var fileChangesRegex: NSRegularExpression?
    @objc var eventLogTypeRaw: String?
    @objc var syncBaseURL: URL?
    @objc var exportMetrics: Bool = false
    @objc var metricURL: URL?
    @objc var metricExportInterval: UInt = 0
    @objc var staticRules: [[String: Any]] = []
    var onStartUSBOptions: SNTDeviceManagerStartupPreferences = .none
}

// MARK: - File Info

@objc class SNTFileInfo: NSObject {
    @objc var infoPlist: [String: Any]?
    @objc var path: String?
    @objc var sha256: String?
    @objc var sha1: String?
    @objc var bundleName: String?
    @objc var bundleVersion: String?
    @objc var bundleShortVersionString: String?
    @objc var quarantineRefererURL: String?
    @objc var quarantineDataURL: String?
    @objc var quarantineTimestamp: Date?
    @objc var quarantineAgentBundleID: String?
    @objc var bundle: Bundle?
    @objc var bundlePath: String?
    
    @objc init?(path: String) {
        super.init()
        self.path = path
        
        // In real implementation, this would read the Info.plist from the bundle
        // For now, return placeholder data
        if path.hasSuffix(".app") {
            let bundlePath = "\(path)/Contents/Info.plist"
            if let plistData = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] {
                self.infoPlist = plist
            }
        } else {
            // For binaries, we'd need to find the associated bundle
            // This is a simplified version
            self.infoPlist = nil
        }
        
        // Placeholder values
        self.sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
        self.sha1 = "0000000000000000000000000000000000000000"
    }
    
    @objc func architectures() -> [String] {
        return []
    }
}

// MARK: - Enums

@objc enum SNTSyncType: Int {
    case normal = 0
    case clean = 1
    case cleanAll = 2
}

enum SNTPushNotificationStatus: Int {
    case disabled = 0
    case disconnected = 1
    case connected = 2
}

enum SNTDeviceManagerStartupPreferences: Int {
    case none = 0
    case unmount = 1
    case forceUnmount = 2
    case remount = 3
    case forceRemount = 4
}

// Note: Standalone client mode has rawValue 2 but we can't add it as an extension
// since SNTClientMode is defined in Objective-C

// MARK: - Rule Count Structure

struct RuleCounts {
    var binary: Int64 = 0
    var certificate: Int64 = 0
    var compiler: Int64 = 0
    var transitive: Int64 = 0
    var teamID: Int64 = 0
    var signingID: Int64 = 0
    var cdhash: Int64 = 0
}

// MARK: - Rule Types

@objc public enum SNTRuleState: Int {
    case unknown = 0
    case allow = 1
    case block = 2
    case silentBlock = 3
    case allowCompiler = 4
    case remove = 5
    case cel = 6
}

@objc public enum SNTRuleType: Int {
    case unknown = 0
    case binary = 1
    case certificate = 2
    case teamID = 3
    case signingID = 4
    case cdHash = 5
}

@objc public class SNTRule: NSObject {
    @objc public var state: SNTRuleState = .unknown
    @objc public var type: SNTRuleType = .binary
    @objc public var identifier: String?
    @objc public var customMsg: String?
    @objc public var customURL: String?
    @objc public var comment: String?
    @objc public var celExpr: String?
    
    @objc public override init() {
        super.init()
    }
}

// MARK: - Constants

let kSantaDPath = "/usr/local/bin/santad"
let kSantaAppPath = "/Applications/Santa.app"

// MARK: - XPC Protocol Extensions

// These are placeholder implementations that will be replaced with actual XPC interfaces
extension SNTDaemonControlXPC {
    func watchdogInfo(reply: @escaping (UInt64, UInt64, Double, Double) -> Void) {
        // Placeholder
        reply(0, 0, 0.0, 0.0)
    }
    
    func cacheCounts(reply: @escaping (UInt64, UInt64) -> Void) {
        // Placeholder
        reply(0, 0)
    }
    
    func databaseEventCount(reply: @escaping (Int64) -> Void) {
        // Placeholder
        reply(0)
    }
    
    func staticRuleCount(reply: @escaping (Int64) -> Void) {
        // Placeholder
        reply(0)
    }
    
    func fullSyncLastSuccess(reply: @escaping (Date?) -> Void) {
        // Placeholder
        reply(nil)
    }
    
    func ruleSyncLastSuccess(reply: @escaping (Date?) -> Void) {
        // Placeholder
        reply(nil)
    }
    
    func syncTypeRequired(reply: @escaping (SNTSyncType) -> Void) {
        // Placeholder
        reply(.normal)
    }
    
    func pushNotificationStatus(reply: @escaping (SNTPushNotificationStatus) -> Void) {
        // Placeholder
        reply(.disabled)
    }
    
    func enableBundles(reply: @escaping (Bool) -> Void) {
        // Placeholder
        reply(false)
    }
    
    func enableTransitiveRules(reply: @escaping (Bool) -> Void) {
        // Placeholder
        reply(false)
    }
    
    func blockUSBMount(reply: @escaping (Bool) -> Void) {
        // Placeholder
        reply(false)
    }
    
    func remountUSBMode(reply: @escaping ([String]) -> Void) {
        // Placeholder
        reply([])
    }
    
    func watchItemsState(reply: @escaping (Bool, UInt64, String?, String?, TimeInterval) -> Void) {
        // Placeholder
        reply(false, 0, nil, nil, 0)
    }
}