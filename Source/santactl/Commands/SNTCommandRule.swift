import Foundation
import CommonCrypto

/// Manage Santa rules
@objc(SNTCommandRule)
class SNTCommandRule: SNTCommand {
    override var shortHelp: String {
        return "Manually add/remove/check rules."
    }
    
    override var longHelp: String {
        return """
        Usage: santactl rule [options]
          One of:
            --allow: add to allow
            --block: add to block
            --silent-block: add to silent block
            --compiler: allow and mark as a compiler
            --cel {cel_expr}: add a CEL rule
                   See https://northpole.dev/features/binary-authorization#cel for more information.
            --remove: remove existing rule
            --check: check for an existing rule
            --import {path}: import rules from a JSON file
            --export {path}: export rules to a JSON file
        
          One of:
            --path {path}: path of binary/bundle to add/remove.
                           Will add an appropriate rule for the file currently at that path.
                           Defaults to a SHA-256 rule unless overridden with another flag.
                           Does not work with --check. Use the fileinfo verb to check
                           the rule state of a file.
            --identifier {sha256|teamID|signingID|cdhash}: identifier to add/remove/check
            --sha256 {sha256}: hash to add/remove/check [deprecated]
        
          Optionally:
            --teamid: add or check a team ID rule instead of binary
            --signingid: add or check a signing ID rule instead of binary (see notes)
            --certificate: add or check a certificate sha256 rule instead of binary
            --cdhash: add or check a cdhash rule instead of binary
            --message {message}: custom message to show when binary is blocked
            --comment {comment}: comment to attach to a new rule
            --clean: clear all non-transitive rules
                Can be combined with --import to clear existing rules before importing.
            --clean-all: clear all rules
                Can be combined with --import to clear existing rules before importing.
        
          Notes:
            The format of `identifier` when adding/checking a `signingid` rule is:
        
              `TeamID:SigningID`
        
            Because signing IDs are controlled by the binary author, this ensures
            that the signing ID is properly scoped to a developer. For the special
            case of platform binaries, `TeamID` should be replaced with the string
            "platform" (e.g. `platform:SigningID`). This allows for rules
            targeting Apple-signed binaries that do not have a team ID.
        
          Importing / Exporting Rules:
            If santa is not configured to use a sync server one can export
            & import its non-static rules to and from JSON files using the
            --export/--import flags. These files have the following form:
        
            {"rules": [{rule-dictionaries}]}
            e.g. {"rules": [
                              {"policy": "BLOCKLIST",
                               "identifier": "84de9c61777ca36b13228e2446d53e966096e78db7a72c632b5c185b2ffe68a6"
                               "custom_url" : "",
                               "custom_msg": "/bin/ls block for demo"}
                              ]}
        
            By default rules are not cleared when importing. To clear the
            database you must use either --clean or --clean-all
        """
    }
    
    override var requiresRoot: Bool {
        return true
    }
    
    override var requiresDaemonConn: Bool {
        return true
    }
    
    override func run(with arguments: [String]) async throws {
        let config = SNTConfigurator.shared
        
        // Check if rules are centrally managed
        if (config.syncBaseURL != nil || config.staticRules.count > 0) && 
           !arguments.contains("--check") && !arguments.contains("--force") {
            printError("SyncBaseURL/StaticRules is set, rules are managed centrally.")
            throw CommandError.invalidOperation
        }
        
        let newRule = SNTRule()
        newRule.state = .unknown
        newRule.type = .binary
        
        var path: String?
        var jsonFilePath: String?
        var check = false
        var cleanupType = SNTRuleCleanup.none
        var importRules = false
        var exportRules = false
        
        // Parse arguments
        var i = 0
        while i < arguments.count {
            let arg = arguments[i]
            
            switch arg.lowercased() {
            case "--allow", "--whitelist":
                newRule.state = .allow
                
            case "--block", "--blacklist":
                newRule.state = .block
                
            case "--silent-block", "--silent-blacklist":
                newRule.state = .silentBlock
                
            case "--compiler":
                newRule.state = .allowCompiler
                
            case "--cel":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                newRule.state = .cel
                newRule.celExpr = arguments[i]
                
            case "--remove":
                newRule.state = .remove
                
            case "--check":
                check = true
                
            case "--certificate":
                newRule.type = .certificate
                
            case "--teamid":
                newRule.type = .teamID
                
            case "--signingid":
                newRule.type = .signingID
                
            case "--cdhash":
                newRule.type = .cdHash
                
            case "--path":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                path = arguments[i]
                
            case "--identifier", "--sha256":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                newRule.identifier = arguments[i]
                
            case "--message":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                newRule.customMsg = arguments[i]
                
            case "--comment":
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                newRule.comment = arguments[i]
                
            case "--import":
                guard !exportRules else {
                    printError("--import and --export are mutually exclusive")
                    throw CommandError.invalidArguments
                }
                importRules = true
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                jsonFilePath = arguments[i]
                
            case "--export":
                guard !importRules else {
                    printError("--import and --export are mutually exclusive")
                    throw CommandError.invalidArguments
                }
                exportRules = true
                i += 1
                guard i < arguments.count else {
                    throw CommandError.invalidArguments
                }
                jsonFilePath = arguments[i]
                
            case "--clean":
                cleanupType = .nonTransitive
                
            case "--clean-all":
                cleanupType = .all
                
            case "--force":
                // DEBUG builds only - allow manual changes
                break
                
            default:
                if !arg.hasPrefix("-") {
                    printError("Unknown argument: \(arg)")
                    throw CommandError.invalidArguments
                }
            }
            
            i += 1
        }
        
        // Validate arguments
        if check {
            if importRules || exportRules || cleanupType != .none {
                printError("--check cannot be combined with import/export/clean operations")
                throw CommandError.invalidArguments
            }
        }
        
        // Handle clean operations
        if !importRules && cleanupType != .none {
            try await performCleanup(cleanupType)
            return
        }
        
        // Handle import/export
        if let jsonPath = jsonFilePath {
            if importRules {
                if newRule.identifier != nil || path != nil || check {
                    printError("--import can only be used by itself")
                    throw CommandError.invalidArguments
                }
                try await importJSONFile(jsonPath, cleanupType: cleanupType)
            } else if exportRules {
                if newRule.identifier != nil || path != nil || check {
                    printError("--export can only be used by itself")
                    throw CommandError.invalidArguments
                }
                try await exportJSONFile(jsonPath)
            }
            return
        }
        
        // Handle path-based rule creation
        if let filePath = path {
            guard let fileInfo = SNTFileInfo(path: filePath) else {
                printError("Provided path was not a plain file")
                throw CommandError.invalidArguments
            }
            
            switch newRule.type {
            case .binary:
                newRule.identifier = fileInfo.sha256
                
            case .certificate:
                if let cs = fileInfo.codesignChecker() {
                    newRule.identifier = cs.leafCertificate?.sha256
                }
                
            case .cdHash:
                if let cs = fileInfo.codesignChecker() {
                    newRule.identifier = cs.cdhash
                }
                
            case .teamID:
                if let cs = fileInfo.codesignChecker() {
                    newRule.identifier = cs.teamID
                }
                
            case .signingID:
                if let cs = fileInfo.codesignChecker() {
                    if let teamID = cs.teamID, !teamID.isEmpty {
                        newRule.identifier = "\(teamID):\(cs.signingID ?? "")"
                    } else if cs.platformBinary {
                        newRule.identifier = "platform:\(cs.signingID ?? "")"
                    }
                }
                
            default:
                break
            }
            
            if newRule.comment == nil {
                newRule.comment = "Rule created from \(filePath)"
            }
        }
        
        // Validate identifier format
        if newRule.type == .binary || newRule.type == .certificate || newRule.type == .cdHash {
            let hexCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
            let cleanedIdentifier = newRule.identifier?.uppercased()
                .trimmingCharacters(in: hexCharacters.inverted) ?? ""
            
            if newRule.type == .binary || newRule.type == .certificate {
                if cleanedIdentifier.count != Int(CC_SHA256_DIGEST_LENGTH) * 2 {
                    printError("BINARY or CERTIFICATE rules require a valid SHA-256")
                    throw CommandError.invalidArguments
                }
            } else if newRule.type == .cdHash {
                if cleanedIdentifier.count != 40 { // CS_CDHASH_LEN * 2
                    printError("CDHASH rules require a valid hex string of length 40")
                    throw CommandError.invalidArguments
                }
            }
        }
        
        // Handle check operation
        if check {
            guard newRule.identifier != nil else {
                printError("--check requires --identifier")
                throw CommandError.invalidArguments
            }
            await printStateOfRule(newRule)
            return
        }
        
        // Validate rule state
        guard newRule.state != .unknown else {
            printError("No state specified")
            throw CommandError.invalidArguments
        }
        
        guard newRule.identifier != nil else {
            printError("A valid SHA-256, CDHash, Signing ID, team ID, or path to file must be specified")
            throw CommandError.invalidArguments
        }
        
        // Add or remove the rule
        try await modifyRule(newRule)
    }
    
    private func performCleanup(_ cleanupType: SNTRuleCleanup) async throws {
        guard let daemon = daemonInterface() else {
            throw CommandError.xpcConnectionFailed
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            daemon.databaseRuleAddRules([], 
                                      ruleCleanup: cleanupType,
                                      source: .santactl) { error in
                if let error = error {
                    self.printError("Failed to delete rules: \(error.localizedDescription)")
                    exit(1)
                } else {
                    print("Successfully cleaned rules")
                    continuation.resume()
                }
            }
        }
    }
    
    private func modifyRule(_ rule: SNTRule) async throws {
        guard let daemon = daemonInterface() else {
            throw CommandError.xpcConnectionFailed
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            daemon.databaseRuleAddRules([rule],
                                      ruleCleanup: .none,
                                      source: .santactl) { error in
                if let error = error {
                    self.printError("Failed to modify rules: \(error.localizedDescription)")
                    exit(1)
                } else {
                    let ruleType: String
                    switch rule.type {
                    case .certificate:
                        ruleType = "Certificate SHA-256"
                    case .binary:
                        ruleType = "SHA-256"
                    case .teamID:
                        ruleType = "Team ID"
                    case .signingID:
                        ruleType = "Signing ID"
                    case .cdHash:
                        ruleType = "CDHash"
                    default:
                        ruleType = "(Unknown type)"
                    }
                    
                    if rule.state == .remove {
                        print("Removed rule for \(ruleType): \(rule.identifier ?? "").")
                    } else {
                        print("Added rule for \(ruleType): \(rule.identifier ?? "").")
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    private func printStateOfRule(_ rule: SNTRule) async {
        guard let daemon = daemonInterface() else {
            print("No daemon connection")
            return
        }
        
        let identifiers = SNTRuleIdentifiers()
        switch rule.type {
        case .cdHash:
            identifiers.cdhash = rule.identifier
        case .binary:
            identifiers.binarySHA256 = rule.identifier
        case .certificate:
            identifiers.certificateSHA256 = rule.identifier
        case .teamID:
            identifiers.teamID = rule.identifier
        case .signingID:
            identifiers.signingID = rule.identifier
        default:
            break
        }
        
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            daemon.databaseRule(for: identifiers) { foundRule in
                if let foundRule = foundRule {
                    continuation.resume(returning: foundRule.humanReadableString())
                } else {
                    continuation.resume(returning: "No matching rule exists")
                }
            }
        }
        
        print(result)
    }
    
    private func importJSONFile(_ path: String, cleanupType: SNTRuleCleanup) async throws {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            printError("Failed to read \(path): \(error.localizedDescription)")
            throw error
        }
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rulesArray = json["rules"] as? [[String: Any]] else {
                printError("Invalid JSON format")
                throw CommandError.invalidArguments
            }
            
            var rules: [SNTRule] = []
            for ruleDict in rulesArray {
                if let rule = SNTRule.fromDictionary(ruleDict) {
                    rules.append(rule)
                }
            }
            
            guard let daemon = daemonInterface() else {
                throw CommandError.xpcConnectionFailed
            }
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                daemon.databaseRuleAddRules(rules,
                                          ruleCleanup: cleanupType,
                                          source: .santactl) { error in
                    if let error = error {
                        self.printError("Failed to import rules: \(error.localizedDescription)")
                        exit(1)
                    } else {
                        print("Successfully imported \(rules.count) rules")
                        continuation.resume()
                    }
                }
            }
        } catch {
            printError("Failed to parse JSON: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func exportJSONFile(_ path: String) async throws {
        guard let daemon = daemonInterface() else {
            throw CommandError.xpcConnectionFailed
        }
        
        let rules = await withCheckedContinuation { (continuation: CheckedContinuation<[SNTRule], Never>) in
            daemon.retrieveAllRules { rules, error in
                if let error = error {
                    self.printError("Failed to retrieve rules: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                } else {
                    continuation.resume(returning: rules ?? [])
                }
            }
        }
        
        var rulesArray: [[String: Any]] = []
        for rule in rules {
            rulesArray.append(rule.toDictionary())
        }
        
        let json = ["rules": rulesArray]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            try data.write(to: URL(fileURLWithPath: path))
            print("Successfully exported \(rules.count) rules to \(path)")
        } catch {
            printError("Failed to write JSON: \(error.localizedDescription)")
            throw error
        }
    }
}

// Extensions for missing functionality
extension SNTRule {
    static func fromDictionary(_ dict: [String: Any]) -> SNTRule? {
        let rule = SNTRule()
        
        // Parse policy/state
        if let policy = dict["policy"] as? String {
            switch policy {
            case "ALLOWLIST":
                rule.state = .allow
            case "BLOCKLIST":
                rule.state = .block
            case "SILENT_BLOCKLIST":
                rule.state = .silentBlock
            case "ALLOWLIST_COMPILER":
                rule.state = .allowCompiler
            case "CEL":
                rule.state = .cel
            default:
                return nil
            }
        }
        
        rule.identifier = dict["identifier"] as? String
        rule.customMsg = dict["custom_msg"] as? String
        rule.customURL = dict["custom_url"] as? String
        rule.comment = dict["comment"] as? String
        rule.celExpr = dict["cel_expr"] as? String
        
        // Parse rule type
        if let ruleType = dict["rule_type"] as? String {
            switch ruleType {
            case "BINARY":
                rule.type = .binary
            case "CERTIFICATE":
                rule.type = .certificate
            case "TEAMID":
                rule.type = .teamID
            case "SIGNINGID":
                rule.type = .signingID
            case "CDHASH":
                rule.type = .cdHash
            default:
                rule.type = .binary
            }
        }
        
        return rule
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        // Set policy
        switch state {
        case .allow:
            dict["policy"] = "ALLOWLIST"
        case .block:
            dict["policy"] = "BLOCKLIST"
        case .silentBlock:
            dict["policy"] = "SILENT_BLOCKLIST"
        case .allowCompiler:
            dict["policy"] = "ALLOWLIST_COMPILER"
        case .cel:
            dict["policy"] = "CEL"
        default:
            break
        }
        
        // Set rule type
        switch type {
        case .binary:
            dict["rule_type"] = "BINARY"
        case .certificate:
            dict["rule_type"] = "CERTIFICATE"
        case .teamID:
            dict["rule_type"] = "TEAMID"
        case .signingID:
            dict["rule_type"] = "SIGNINGID"
        case .cdHash:
            dict["rule_type"] = "CDHASH"
        default:
            break
        }
        
        if let identifier = identifier {
            dict["identifier"] = identifier
        }
        if let customMsg = customMsg {
            dict["custom_msg"] = customMsg
        }
        if let customURL = customURL {
            dict["custom_url"] = customURL
        }
        if let comment = comment {
            dict["comment"] = comment
        }
        if let celExpr = celExpr {
            dict["cel_expr"] = celExpr
        }
        
        return dict
    }
}

// Placeholder enums and extensions
enum SNTRuleCleanup: Int {
    case none = 0
    case nonTransitive = 1
    case all = 2
}

enum SNTRuleAddSource: Int {
    case syncService = 0
    case santactl = 1
}

extension SNTDaemonControlXPC {
    func databaseRuleAddRules(_ rules: [SNTRule], 
                            ruleCleanup: SNTRuleCleanup,
                            source: SNTRuleAddSource,
                            reply: @escaping (Error?) -> Void) {
        // Placeholder
    }
    
    func retrieveAllRules(reply: @escaping ([SNTRule]?, Error?) -> Void) {
        // Placeholder
    }
}

extension MOLCodesignChecker {
    @objc var platformBinary: Bool {
        // Placeholder
        return false
    }
}