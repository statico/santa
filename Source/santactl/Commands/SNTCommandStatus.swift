import Foundation

/// Display Santa status information
@objc(SNTCommandStatus)
class SNTCommandStatus: SNTCommand {
    override var shortHelp: String {
        return "Show Santa status information."
    }
    
    override var longHelp: String {
        return """
        Provides details about Santa while it's running.
          Use --json to output in JSON format
        """
    }
    
    override var requiresRoot: Bool {
        return false
    }
    
    override var requiresDaemonConn: Bool {
        return true
    }
    
    override func run(with arguments: [String]) async throws {
        guard let daemon = daemonInterface() else {
            throw CommandError.xpcConnectionFailed
        }
        
        let isJSON = arguments.contains("--json")
        
        // Collect all status information
        let status = try await collectStatus(from: daemon)
        
        if isJSON {
            outputJSON(status)
        } else {
            outputHuman(status)
        }
    }
    
    private func collectStatus(from daemon: SNTDaemonControlXPC) async throws -> StatusInfo {
        var status = StatusInfo()
        
        // Get client mode
        let clientMode = await withCheckedContinuation { continuation in
            daemon.clientMode { mode in
                continuation.resume(returning: mode)
            }
        }
        status.clientMode = clientModeString(clientMode)
        
        // Get watchdog info
        let watchdogInfo = await withCheckedContinuation { continuation in
            daemon.watchdogInfo { cpuEvents, ramEvents, cpuPeak, ramPeak in
                continuation.resume(returning: (cpuEvents, ramEvents, cpuPeak, ramPeak))
            }
        }
        status.watchdogCPUEvents = watchdogInfo.0
        status.watchdogRAMEvents = watchdogInfo.1
        status.watchdogCPUPeak = watchdogInfo.2
        status.watchdogRAMPeak = watchdogInfo.3
        
        // Get cache counts
        let cacheCounts = await withCheckedContinuation { continuation in
            daemon.cacheCounts { rootCache, nonRootCache in
                continuation.resume(returning: (rootCache, nonRootCache))
            }
        }
        status.rootCacheCount = cacheCounts.0
        status.nonRootCacheCount = cacheCounts.1
        
        // Get database rule counts
        let _ = await withCheckedContinuation { continuation in
            daemon.databaseRuleCounts { counts in
                continuation.resume(returning: counts)
            }
        }
        // TODO: Convert ruleCounts properly
        // status.ruleCounts = ruleCounts
        
        // Get event count
        status.eventCount = await withCheckedContinuation { continuation in
            daemon.databaseEventCount { count in
                continuation.resume(returning: count)
            }
        }
        
        // Get static rule count
        status.staticRuleCount = await withCheckedContinuation { continuation in
            daemon.staticRuleCount { count in
                continuation.resume(returning: count)
            }
        }
        
        // Get sync status
        status.fullSyncLastSuccess = await withCheckedContinuation { continuation in
            daemon.fullSyncLastSuccess { date in
                continuation.resume(returning: date)
            }
        }
        
        status.ruleSyncLastSuccess = await withCheckedContinuation { continuation in
            daemon.ruleSyncLastSuccess { date in
                continuation.resume(returning: date)
            }
        }
        
        status.syncCleanRequired = await withCheckedContinuation { continuation in
            daemon.syncTypeRequired { syncType in
                continuation.resume(returning: syncType == .clean || syncType == .cleanAll)
            }
        }
        
        // Get other settings from configurator
        let configurator = SNTConfigurator.shared
        status.fileLogging = configurator.fileChangesRegex != nil
        status.eventLogType = configurator.eventLogTypeRaw?.lowercased() ?? "unknown"
        status.syncURL = configurator.syncBaseURL?.absoluteString
        status.exportMetrics = configurator.exportMetrics
        status.metricURL = configurator.metricURL?.absoluteString
        status.metricExportInterval = configurator.metricExportInterval
        
        // Get push notification status if sync is configured
        if configurator.syncBaseURL != nil {
            status.pushNotifications = await getPushNotificationStatus(from: daemon)
        }
        
        // Get bundle and transitive rules status
        status.enableBundles = await withCheckedContinuation { continuation in
            daemon.enableBundles { enabled in
                continuation.resume(returning: enabled)
            }
        }
        
        status.enableTransitiveRules = await withCheckedContinuation { continuation in
            daemon.enableTransitiveRules { enabled in
                continuation.resume(returning: enabled)
            }
        }
        
        // Get USB blocking status
        status.blockUSBMount = await withCheckedContinuation { continuation in
            daemon.blockUSBMount { enabled in
                continuation.resume(returning: enabled)
            }
        }
        
        if status.blockUSBMount {
            status.remountUSBMode = await withCheckedContinuation { continuation in
                daemon.remountUSBMode { modes in
                    continuation.resume(returning: modes)
                }
            }
        }
        
        status.onStartUSBOptions = startupOptionToString(configurator.onStartUSBOptions)
        
        // Get watch items status
        let watchItemsState = await withCheckedContinuation { continuation in
            daemon.watchItemsState { enabled, ruleCount, policyVersion, configPath, lastUpdateEpoch in
                continuation.resume(returning: (enabled, ruleCount, policyVersion, configPath, lastUpdateEpoch))
            }
        }
        status.watchItemsEnabled = watchItemsState.0
        if status.watchItemsEnabled {
            status.watchItemsRuleCount = watchItemsState.1
            status.watchItemsPolicyVersion = watchItemsState.2
            status.watchItemsConfigPath = watchItemsState.3
            status.watchItemsLastUpdateEpoch = watchItemsState.4
        }
        
        return status
    }
    
    private func getPushNotificationStatus(from daemon: SNTDaemonControlXPC) async -> String {
        return await withTaskGroup(of: String.self) { group in
            group.addTask {
                return await withCheckedContinuation { continuation in
                    daemon.pushNotificationStatus { status in
                        let statusString: String
                        switch status {
                        case .disabled:
                            statusString = "Disabled"
                        case .disconnected:
                            statusString = "Disconnected"
                        case .connected:
                            statusString = "Connected"
                        @unknown default:
                            statusString = "Unknown"
                        }
                        continuation.resume(returning: statusString)
                    }
                }
            }
            
            group.addTask {
                // Timeout after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                return "Unknown"
            }
            
            // Return first result (either actual status or timeout)
            for await result in group {
                group.cancelAll()
                return result
            }
            
            return "Unknown"
        }
    }
    
    private func outputJSON(_ status: StatusInfo) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss Z"
        
        let fullSyncLastSuccessStr = status.fullSyncLastSuccess.map { dateFormatter.string(from: $0) } ?? "Never"
        let ruleSyncLastSuccessStr = status.ruleSyncLastSuccess.map { dateFormatter.string(from: $0) } ?? fullSyncLastSuccessStr
        let watchItemsLastUpdateStr = dateFormatter.string(from: Date(timeIntervalSince1970: status.watchItemsLastUpdateEpoch))
        
        var json: [String: Any] = [
            "daemon": [
                "driver_connected": true,
                "mode": status.clientMode,
                "transitive_rules": status.enableTransitiveRules,
                "log_type": status.eventLogType,
                "file_logging": status.fileLogging,
                "watchdog_cpu_events": status.watchdogCPUEvents,
                "watchdog_ram_events": status.watchdogRAMEvents,
                "watchdog_cpu_peak": status.watchdogCPUPeak,
                "watchdog_ram_peak": status.watchdogRAMPeak,
                "block_usb": status.blockUSBMount,
                "remount_usb_mode": status.blockUSBMount && !status.remountUSBMode.isEmpty ? status.remountUSBMode : [],
                "on_start_usb_options": status.onStartUSBOptions
            ],
            "database": [
                "binary_rules": status.ruleCounts.binary,
                "certificate_rules": status.ruleCounts.certificate,
                "teamid_rules": status.ruleCounts.teamID,
                "signingid_rules": status.ruleCounts.signingID,
                "cdhash_rules": status.ruleCounts.cdhash,
                "compiler_rules": status.ruleCounts.compiler,
                "transitive_rules": status.ruleCounts.transitive,
                "events_pending_upload": status.eventCount
            ],
            "static_rules": [
                "rule_count": status.staticRuleCount
            ],
            "sync": [
                "server": status.syncURL ?? "null",
                "clean_required": status.syncCleanRequired,
                "last_successful_full": fullSyncLastSuccessStr,
                "last_successful_rule": ruleSyncLastSuccessStr,
                "push_notifications": status.pushNotifications,
                "bundle_scanning": status.enableBundles
            ],
            "cache": [
                "root_cache_count": status.rootCacheCount,
                "non_root_cache_count": status.nonRootCacheCount
            ]
        ]
        
        if status.watchItemsEnabled {
            json["watch_items"] = [
                "enabled": true,
                "rule_count": status.watchItemsRuleCount,
                "policy_version": status.watchItemsPolicyVersion ?? "",
                "config_path": status.watchItemsConfigPath ?? "null",
                "last_policy_update": watchItemsLastUpdateStr
            ]
        } else {
            json["watch_items"] = ["enabled": false]
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    private func outputHuman(_ status: StatusInfo) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss Z"
        
        print(">>> Daemon Info")
        print("  \(pad("Mode", 25)) | \(status.clientMode)")
        
        if status.enableTransitiveRules {
            print("  \(pad("Transitive Rules", 25)) | Yes")
        }
        
        print("  \(pad("Log Type", 25)) | \(status.eventLogType)")
        print("  \(pad("File Logging", 25)) | \(status.fileLogging ? "Yes" : "No")")
        print("  \(pad("USB Blocking", 25)) | \(status.blockUSBMount ? "Yes" : "No")")
        
        if status.blockUSBMount && !status.remountUSBMode.isEmpty {
            print("  \(pad("USB Remounting Mode", 25)) | \(status.remountUSBMode.joined(separator: ", "))")
        }
        
        print("  \(pad("On Start USB Options", 25)) | \(status.onStartUSBOptions)")
        print("  \(pad("Watchdog CPU Events", 25)) | \(status.watchdogCPUEvents)  (Peak: \(String(format: "%.2f", status.watchdogCPUPeak))%)")
        print("  \(pad("Watchdog RAM Events", 25)) | \(status.watchdogRAMEvents)  (Peak: \(String(format: "%.2f", status.watchdogRAMPeak))MB)")
        
        print(">>> Cache Info")
        print("  \(pad("Root cache count", 25)) | \(status.rootCacheCount)")
        print("  \(pad("Non-root cache count", 25)) | \(status.nonRootCacheCount)")
        
        print(">>> Database Info")
        print("  \(pad("Binary Rules", 25)) | \(status.ruleCounts.binary)")
        print("  \(pad("Certificate Rules", 25)) | \(status.ruleCounts.certificate)")
        print("  \(pad("TeamID Rules", 25)) | \(status.ruleCounts.teamID)")
        print("  \(pad("SigningID Rules", 25)) | \(status.ruleCounts.signingID)")
        print("  \(pad("CDHash Rules", 25)) | \(status.ruleCounts.cdhash)")
        print("  \(pad("Compiler Rules", 25)) | \(status.ruleCounts.compiler)")
        print("  \(pad("Transitive Rules", 25)) | \(status.ruleCounts.transitive)")
        print("  \(pad("Events Pending Upload", 25)) | \(status.eventCount)")
        
        if SNTConfigurator.shared.staticRules.count > 0 {
            print(">>> Static Rules")
            print("  \(pad("Rules", 25)) | \(status.staticRuleCount)")
        }
        
        print(">>> Watch Items")
        print("  \(pad("Enabled", 25)) | \(status.watchItemsEnabled ? "Yes" : "No")")
        
        if status.watchItemsEnabled {
            print("  \(pad("Policy Version", 25)) | \(status.watchItemsPolicyVersion ?? "")")
            print("  \(pad("Rule Count", 25)) | \(status.watchItemsRuleCount)")
            print("  \(pad("Config Path", 25)) | \(status.watchItemsConfigPath ?? "(embedded)")")
            let watchItemsLastUpdateStr = dateFormatter.string(from: Date(timeIntervalSince1970: status.watchItemsLastUpdateEpoch))
            print("  \(pad("Last Policy Update", 25)) | \(watchItemsLastUpdateStr)")
        }
        
        if let syncURL = status.syncURL {
            print(">>> Sync Info")
            print("  \(pad("Sync Server", 25)) | \(syncURL)")
            print("  \(pad("Clean Sync Required", 25)) | \(status.syncCleanRequired ? "Yes" : "No")")
            
            let fullSyncStr = status.fullSyncLastSuccess.map { dateFormatter.string(from: $0) } ?? "Never"
            let ruleSyncStr = status.ruleSyncLastSuccess.map { dateFormatter.string(from: $0) } ?? fullSyncStr
            
            print("  \(pad("Last Successful Full Sync", 25)) | \(fullSyncStr)")
            print("  \(pad("Last Successful Rule Sync", 25)) | \(ruleSyncStr)")
            print("  \(pad("Push Notifications", 25)) | \(status.pushNotifications)")
            print("  \(pad("Bundle Scanning", 25)) | \(status.enableBundles ? "Yes" : "No")")
        }
        
        if status.exportMetrics {
            print(">>> Metrics Info")
            if let metricURL = status.metricURL {
                print("  \(pad("Metrics Server", 25)) | \(metricURL)")
            }
            print("  \(pad("Export Interval (seconds)", 25)) | \(status.metricExportInterval)")
        }
    }
    
    private func pad(_ string: String, _ length: Int) -> String {
        return string.padding(toLength: length, withPad: " ", startingAt: 0)
    }
    
    private func clientModeString(_ mode: SNTClientMode) -> String {
        switch mode {
        case .monitor:
            return "Monitor"
        case .lockdown:
            return "Lockdown"
        default:
            // Check if it's standalone mode (rawValue == 2)
            if mode.rawValue == 2 {
                return "Standalone"
            }
            return "Unknown (\(mode.rawValue))"
        }
    }
    
    private func startupOptionToString(_ pref: SNTDeviceManagerStartupPreferences) -> String {
        switch pref {
        case .unmount:
            return "Unmount"
        case .forceUnmount:
            return "ForceUnmount"
        case .remount:
            return "Remount"
        case .forceRemount:
            return "ForceRemount"
        default:
            return "None"
        }
    }
}

// Status info struct to hold all collected data
private struct StatusInfo {
    var clientMode = "Unknown"
    var watchdogCPUEvents: UInt64 = 0
    var watchdogRAMEvents: UInt64 = 0
    var watchdogCPUPeak: Double = 0
    var watchdogRAMPeak: Double = 0
    var fileLogging = false
    var eventLogType = "unknown"
    var rootCacheCount: UInt64 = 0
    var nonRootCacheCount: UInt64 = 0
    var ruleCounts = RuleCounts()
    var eventCount: Int64 = 0
    var staticRuleCount: Int64 = 0
    var fullSyncLastSuccess: Date?
    var ruleSyncLastSuccess: Date?
    var syncCleanRequired = false
    var pushNotifications = "Unknown"
    var enableBundles = false
    var enableTransitiveRules = false
    var blockUSBMount = false
    var remountUSBMode: [String] = []
    var onStartUSBOptions = "None"
    var watchItemsEnabled = false
    var watchItemsRuleCount: UInt64 = 0
    var watchItemsPolicyVersion: String?
    var watchItemsConfigPath: String?
    var watchItemsLastUpdateEpoch: TimeInterval = 0
    var syncURL: String?
    var exportMetrics = false
    var metricURL: String?
    var metricExportInterval: UInt = 0
}

// Types are now defined in PlaceholderTypes.swift