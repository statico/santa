import Foundation

/// Display file information including code signing details
@objc(SNTCommandFileInfo)
class SNTCommandFileInfo: SNTCommand {
    // Properties set from command line flags
    private var recursive = false
    private var jsonOutput = false
    private var bundleInfo = false
    private var enableEntitlements = false
    private var filterInclusive = false
    private var certIndex: Int?
    private var outputKeyList: [String] = []
    private var outputFilters: [String: NSRegularExpression] = [:]
    
    // Flag indicating when to use TTY colors
    private var prettyOutput: Bool {
        return isatty(STDOUT_FILENO) == 1 && !jsonOutput
    }
    
    // Common date formatter
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss Z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    // Maximum length of output key name, used for formatting
    private var maxKeyWidth: Int = 0
    
    override var shortHelp: String {
        return "Prints information about a file."
    }
    
    override var longHelp: String {
        return """
        The details provided will be the same ones Santa uses to make a decision
        about executables. This includes SHA-256, SHA-1, code signing information and
        the type of file.
        
        Usage: santactl fileinfo [options] [file-paths]
            --recursive (-r): Search directories recursively.
                              Incompatible with --bundleinfo.
            --json: Output in JSON format.
            --key: Search and return this one piece of information.
                   You may specify multiple keys by repeating this flag.
                   Valid Keys:
                       "Path"
                       "SHA-256"
                       "SHA-1"
                       "Bundle Name"
                       "Bundle Version"
                       "Bundle Version Str"
                       "Team ID"
                       "Signing ID"
                       "CDHash"
                       "Type"
                       "Page Zero"
                       "Code-signed"
                       "Rule"
                       "Entitlements"
                       "Signing Chain"
            --cert-index: Supply an integer corresponding to a certificate of the
                          signing chain to show info only for that certificate.
            --localtz: Use timestamps in the local timezone for all dates, instead of UTC.
            --filter: Use predicates of the form 'key=regex' to filter out which files
                      are displayed.
            --filter-inclusive: If multiple filters are specified, they must all match
                                for the file to be displayed.
            --entitlements: If the file has entitlements, will also display them
            --bundleinfo: If the file is part of a bundle, will also display bundle
                          hash information.
        
        Examples: santactl fileinfo --key SHA-256 --json /usr/bin/yes
                  santactl fileinfo /usr/bin/yes /bin/*
                  santactl fileinfo /usr/bin -r --key Path --key SHA-256 --key Rule
        """
    }
    
    override var requiresRoot: Bool {
        return false
    }
    
    override var requiresDaemonConn: Bool {
        return false
    }
    
    override func run(with arguments: [String]) async throws {
        guard !arguments.isEmpty else {
            printError("No arguments")
            print(longHelp)
            throw CommandError.invalidArguments
        }
        
        let filePaths = try parseFileInfoArguments(arguments)
        
        // Set up output key list if not specified
        if outputKeyList.isEmpty {
            if certIndex != nil {
                outputKeyList = ["SHA-256", "SHA-1", "Common Name", "Organization", 
                               "Organizational Unit", "Valid From", "Valid Until"]
            } else {
                outputKeyList = ["Path", "SHA-256", "SHA-1", "Bundle Name", "Bundle Version",
                               "Bundle Version Str", "Team ID", "Signing ID", "CDHash", 
                               "Type", "Page Zero", "Code-signed", "Rule", "Signing Chain"]
            }
        }
        
        // Calculate max key width for formatting
        maxKeyWidth = outputKeyList.map { $0.count }.max() ?? 0
        
        // Start JSON array if needed
        if jsonOutput {
            print("[")
        }
        
        var isFirstEntry = true
        let fileManager = FileManager.default
        let cwd = fileManager.currentDirectoryPath
        
        // Process each file path
        for path in filePaths {
            var fullPath = (path as NSString).standardizingPath
            if !path.hasPrefix("/") {
                fullPath = (cwd as NSString).appendingPathComponent(fullPath)
            }
            
            await processPath(fullPath, isFirstEntry: &isFirstEntry)
        }
        
        // Close JSON array if needed
        if jsonOutput {
            print("\n]")
        }
    }
    
    private func processPath(_ path: String, isFirstEntry: inout Bool) async {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            printError("File does not exist: \(path)")
            return
        }
        
        if isDir.boolValue {
            if recursive {
                // Process directory recursively
                if let enumerator = fileManager.enumerator(atPath: path) {
                    while let file = enumerator.nextObject() as? String {
                        let filepath = (path as NSString).appendingPathComponent(file)
                        var fileIsDir: ObjCBool = false
                        if fileManager.fileExists(atPath: filepath, isDirectory: &fileIsDir),
                           !fileIsDir.boolValue {
                            await printInfoForFile(filepath, isFirstEntry: &isFirstEntry)
                        }
                    }
                }
            } else {
                printError("\(path) is a directory. Use the -r flag to search recursively.")
            }
        } else {
            await printInfoForFile(path, isFirstEntry: &isFirstEntry)
        }
    }
    
    private func printInfoForFile(_ path: String, isFirstEntry: inout Bool) async {
        guard let fileInfo = SNTFileInfo(path: path) else {
            printError("Invalid or empty file: \(path)")
            return
        }
        
        var outputDict: [String: Any] = [:]
        
        // Collect file information
        outputDict["Path"] = path
        outputDict["SHA-256"] = fileInfo.sha256 ?? ""
        outputDict["SHA-1"] = fileInfo.sha1 ?? ""
        outputDict["Bundle Name"] = fileInfo.bundleName ?? ""
        outputDict["Bundle Version"] = fileInfo.bundleVersion ?? ""
        outputDict["Bundle Version Str"] = fileInfo.bundleShortVersionString ?? ""
        outputDict["Type"] = fileInfo.humanReadableFileType() ?? "Unknown"
        
        // Code signing information
        if let csc = fileInfo.codesignChecker() {
            outputDict["Team ID"] = csc.teamID ?? ""
            outputDict["Signing ID"] = csc.signingID ?? ""
            outputDict["CDHash"] = csc.cdhash ?? ""
            outputDict["Code-signed"] = fileInfo.codesignStatus() ?? "No"
            
            if enableEntitlements {
                outputDict["Entitlements"] = csc.entitlements ?? [:]
            }
            
            // Signing chain
            if let certs = csc.certificates, !certs.isEmpty {
                var signingChain: [[String: String]] = []
                for cert in certs {
                    signingChain.append([
                        "SHA-256": cert.sha256 ?? "",
                        "SHA-1": cert.sha1 ?? "",
                        "Common Name": cert.commonName ?? "",
                        "Organization": cert.orgName ?? "",
                        "Organizational Unit": cert.orgUnit ?? "",
                        "Valid From": dateFormatter.string(from: cert.validFrom ?? Date()),
                        "Valid Until": dateFormatter.string(from: cert.validUntil ?? Date())
                    ])
                }
                outputDict["Signing Chain"] = signingChain
            }
        }
        
        // Check page zero
        if fileInfo.isMissingPageZero() {
            outputDict["Page Zero"] = "__PAGEZERO segment missing/bad!"
        }
        
        // Get rule from daemon if connected
        if let daemon = daemonInterface() {
            outputDict["Rule"] = await getRuleForFile(fileInfo, daemon: daemon)
        } else {
            outputDict["Rule"] = "No daemon connection"
        }
        
        // Apply filters if any
        if !outputFilters.isEmpty && !shouldOutput(outputDict) {
            return
        }
        
        // Filter output to requested keys
        var filteredOutput: [String: Any] = [:]
        for key in outputKeyList {
            if let value = outputDict[key] {
                filteredOutput[key] = value
            }
        }
        
        // Output the information
        if jsonOutput {
            if !isFirstEntry {
                print(",")
            }
            isFirstEntry = false
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: filteredOutput, 
                                                         options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString, terminator: "")
            }
        } else {
            // Human readable output
            for key in outputKeyList {
                if let value = filteredOutput[key] {
                    if key == "Signing Chain", let chain = value as? [[String: String]] {
                        printSigningChain(chain)
                    } else if key == "Entitlements", let entitlements = value as? [String: Any] {
                        printEntitlements(entitlements)
                    } else {
                        print("\(key.padding(toLength: maxKeyWidth, withPad: " ", startingAt: 0)): \(value)")
                    }
                }
            }
            print() // Empty line between files
        }
    }
    
    private func getRuleForFile(_ fileInfo: SNTFileInfo, daemon: SNTDaemonControlXPC) async -> String {
        // Create rule identifiers
        let identifiers = SNTRuleIdentifiers()
        identifiers.cdhash = fileInfo.codesignChecker()?.cdhash
        identifiers.binarySHA256 = fileInfo.sha256
        identifiers.signingID = fileInfo.codesignChecker()?.signingID
        identifiers.certificateSHA256 = fileInfo.codesignChecker()?.leafCertificate?.sha256
        identifiers.teamID = fileInfo.codesignChecker()?.teamID
        
        return await withCheckedContinuation { continuation in
            daemon.databaseRule(for: identifiers) { rule in
                if let rule = rule {
                    continuation.resume(returning: rule.humanReadableString())
                } else {
                    continuation.resume(returning: "None")
                }
            }
        }
    }
    
    private func printSigningChain(_ chain: [[String: String]]) {
        print("Signing Chain:")
        for (index, cert) in chain.enumerated() {
            print("   \(index + 1). SHA-256             : \(cert["SHA-256"] ?? "")")
            print("       SHA-1               : \(cert["SHA-1"] ?? "")")
            print("       Common Name         : \(cert["Common Name"] ?? "")")
            print("       Organization        : \(cert["Organization"] ?? "")")
            print("       Organizational Unit : \(cert["Organizational Unit"] ?? "")")
            print("       Valid From          : \(cert["Valid From"] ?? "")")
            print("       Valid Until         : \(cert["Valid Until"] ?? "")")
            if index < chain.count - 1 {
                print()
            }
        }
    }
    
    private func printEntitlements(_ entitlements: [String: Any]) {
        if entitlements.isEmpty {
            print("\(String("Entitlements".padding(toLength: maxKeyWidth, withPad: " ", startingAt: 0))): None")
            return
        }
        
        print("Entitlements:")
        var index = 0
        for (key, value) in entitlements.sorted(by: { $0.key < $1.key }) {
            index += 1
            if let boolValue = value as? Bool {
                if boolValue {
                    print("   \(index). \(key)")
                }
            } else {
                print("   \(index). \(key): \(value)")
            }
        }
    }
    
    private func shouldOutput(_ info: [String: Any]) -> Bool {
        var matches = 0
        
        for (key, regex) in outputFilters {
            if let value = info[key] as? String {
                if regex.firstMatch(in: value, range: NSRange(location: 0, length: value.count)) != nil {
                    matches += 1
                }
            }
        }
        
        return filterInclusive ? matches == outputFilters.count : matches > 0
    }
    
    private func parseFileInfoArguments(_ arguments: [String]) throws -> [String] {
        var paths: [String] = []
        var keys: [String] = []
        var filters: [String: NSRegularExpression] = [:]
        
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            
            switch arg.lowercased() {
            case "--json":
                jsonOutput = true
                
            case "--recursive", "-r":
                if bundleInfo {
                    throw CommandError.invalidArguments
                }
                recursive = true
                
            case "--bundleinfo", "-b":
                if recursive || certIndex != nil {
                    throw CommandError.invalidArguments
                }
                bundleInfo = true
                
            case "--entitlements":
                enableEntitlements = true
                
            case "--filter-inclusive":
                filterInclusive = true
                
            case "--localtz":
                dateFormatter.timeZone = TimeZone.current
                
            case "--cert-index":
                i += 1
                guard i < arguments.count, let index = Int(arguments[i]) else {
                    throw CommandError.invalidArguments
                }
                certIndex = index
                
            case "--key":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                keys.append(arguments[i])
                
            case "--filter":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                let filterArg = arguments[i]
                guard let equalIndex = filterArg.firstIndex(of: "=") else {
                    throw CommandError.invalidArguments
                }
                let key = String(filterArg[..<equalIndex])
                let pattern = String(filterArg[filterArg.index(after: equalIndex)...])
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                    throw CommandError.invalidArguments
                }
                filters[key] = regex
                
            default:
                if !arg.hasPrefix("-") {
                    paths.append(arg)
                }
            }
            
            i += 1
        }
        
        guard !paths.isEmpty else {
            throw CommandError.invalidArguments
        }
        
        if !keys.isEmpty {
            outputKeyList = keys
        }
        outputFilters = filters
        
        return paths
    }
}

// Placeholder extensions for missing types
extension SNTFileInfo {
    func humanReadableFileType() -> String? {
        // Will be provided by actual implementation
        return "Executable"
    }
    
    func codesignChecker() -> MOLCodesignChecker? {
        // Will be provided by actual implementation
        return nil
    }
    
    func codesignStatus() -> String? {
        // Will be provided by actual implementation
        return "Unknown"
    }
    
    func isMissingPageZero() -> Bool {
        // Will be provided by actual implementation
        return false
    }
}

@objc class MOLCodesignChecker: NSObject {
    @objc var teamID: String?
    @objc var signingID: String?
    @objc var cdhash: String?
    @objc var certificates: [MOLCertificate]?
    @objc var entitlements: [String: Any]?
    @objc var leafCertificate: MOLCertificate? {
        return certificates?.first
    }
}

@objc class MOLCertificate: NSObject {
    @objc var sha256: String?
    @objc var sha1: String?
    @objc var commonName: String?
    @objc var orgName: String?
    @objc var orgUnit: String?
    @objc var validFrom: Date?
    @objc var validUntil: Date?
}

@objc class SNTRuleIdentifiers: NSObject {
    @objc var cdhash: String?
    @objc var binarySHA256: String?
    @objc var signingID: String?
    @objc var certificateSHA256: String?
    @objc var teamID: String?
}

extension SNTDaemonControlXPC {
    func databaseRule(for identifiers: SNTRuleIdentifiers, reply: @escaping (SNTRule?) -> Void) {
        // Placeholder
    }
}

extension SNTRule {
    func humanReadableString() -> String {
        // Placeholder
        return "ALLOW"
    }
}