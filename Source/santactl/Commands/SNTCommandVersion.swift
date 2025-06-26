import Foundation

/// Show Santa component versions
@objc(SNTCommandVersion)
class SNTCommandVersion: SNTCommand {
    override var shortHelp: String {
        return "Show Santa component versions."
    }
    
    override var longHelp: String {
        return """
        Show versions of all Santa components.
          Use --json to output in JSON format.
        """
    }
    
    override var requiresRoot: Bool {
        return false
    }
    
    override var requiresDaemonConn: Bool {
        return false
    }
    
    override func run(with arguments: [String]) async throws {
        let isJSON = arguments.contains("--json")
        
        let santadVersion = getSantadVersion()
        let santactlVersion = getSantactlVersion()
        let santaGUIVersion = getSantaAppVersion()
        
        if isJSON {
            let versions = [
                "santad": santadVersion,
                "santactl": santactlVersion,
                "SantaGUI": santaGUIVersion
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: versions, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("\(pad("santad", 15)) | \(santadVersion)")
            print("\(pad("santactl", 15)) | \(santactlVersion)")
            print("\(pad("SantaGUI", 15)) | \(santaGUIVersion)")
        }
    }
    
    private func composeVersions(from dict: [String: Any]?) -> String {
        guard let dict = dict,
              let bundleVersion = dict["CFBundleVersion"] as? String else {
            return ""
        }
        
        let productVersion = dict["CFBundleShortVersionString"] as? String ?? ""
        let buildVersion = bundleVersion.components(separatedBy: ".").last ?? ""
        
        var commitHash = dict["SNTCommitHash"] as? String ?? ""
        if commitHash.count > 8 {
            commitHash = String(commitHash.prefix(8))
        }
        
        return "\(productVersion) (build \(buildVersion), commit \(commitHash))"
    }
    
    private func getSantadVersion() -> String {
        let daemonInfo = SNTFileInfo(path: kSantaDPath)
        return composeVersions(from: daemonInfo?.infoPlist)
    }
    
    private func getSantaAppVersion() -> String {
        let guiInfo = SNTFileInfo(path: kSantaAppPath)
        return composeVersions(from: guiInfo?.infoPlist)
    }
    
    private func getSantactlVersion() -> String {
        return composeVersions(from: Bundle.main.infoDictionary)
    }
    
    private func pad(_ string: String, _ length: Int) -> String {
        return string.padding(toLength: length, withPad: " ", startingAt: 0)
    }
}

// Types are now defined in PlaceholderTypes.swift