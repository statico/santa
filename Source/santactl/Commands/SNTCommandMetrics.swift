import Foundation

/// Show Santa metric information
@objc(SNTCommandMetrics)
class SNTCommandMetrics: SNTCommand {
    override var shortHelp: String {
        return "Show Santa metric information."
    }
    
    override var longHelp: String {
        return """
        Provides metrics about Santa's operation while it's running.
        Pass prefixes to filter list of metrics, if desired.
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
        
        let metrics = await withCheckedContinuation { (continuation: CheckedContinuation<[String: Any], Never>) in
            daemon.metrics { exportedMetrics in
                continuation.resume(returning: exportedMetrics ?? [:])
            }
        }
        
        let filteredMetrics = filterMetrics(metrics, withArguments: arguments)
        
        let exportJSON = arguments.contains("--json")
        prettyPrintMetrics(filteredMetrics, asJSON: exportJSON)
    }
    
    private func filterMetrics(_ metrics: [String: Any], withArguments args: [String]) -> [String: Any] {
        var outer = metrics
        var inner: [String: Any] = [:]
        var hadFilter = false
        
        if let metricsDict = metrics["metrics"] as? [String: Any] {
            for (key, value) in metricsDict {
                for arg in args {
                    if arg.hasPrefix("-") { continue }
                    
                    hadFilter = true
                    if key.hasPrefix(arg) {
                        inner[key] = value
                    }
                }
            }
        }
        
        if hadFilter {
            outer["metrics"] = inner
        }
        
        return outer
    }
    
    private func prettyPrintMetrics(_ metrics: [String: Any], asJSON exportJSON: Bool) {
        let normalizedMetrics = convertDatesToISO8601Strings(metrics)
        
        if exportJSON {
            // Format as JSON
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: normalizedMetrics,
                                                         options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                printError("Failed to serialize metrics to JSON: \(error)")
            }
            return
        }
        
        // Check if metrics are configured
        if !SNTConfigurator.shared.exportMetrics {
            print("Metrics not configured\n")
            return
        }
        
        // Print metrics info
        print(">>> Metrics Info")
        if let metricsURL = SNTConfigurator.shared.metricURL {
            print(String(format: "  %-25s | %s", "Metrics Server", metricsURL.absoluteString))
        }
        let metricFormat = metricStringFromMetricFormatType(SNTConfigurator.shared.metricFormat)
        print(String(format: "  %-25s | %s", "Metrics Format", metricFormat))
        print(String(format: "  %-25s | %lu", "Export Interval (seconds)", SNTConfigurator.shared.metricExportInterval))
        print()
        
        // Print root labels
        if let rootLabels = normalizedMetrics["root_labels"] as? [String: String] {
            print(">>> Root Labels")
            prettyPrintRootLabels(rootLabels)
            print()
        }
        
        // Print metrics
        if let metricsDict = normalizedMetrics["metrics"] as? [String: Any] {
            print(">>> Metrics")
            prettyPrintMetricValues(metricsDict)
        }
    }
    
    private func prettyPrintRootLabels(_ rootLabels: [String: String]) {
        for (label, value) in rootLabels {
            print(String(format: "  %-25s | %s", label, value))
        }
    }
    
    private func prettyPrintMetricValues(_ metrics: [String: Any]) {
        for (metricName, metricData) in metrics {
            guard let metric = metricData as? [String: Any] else { continue }
            
            print(String(format: "  %-25s | %s", "Metric Name", metricName))
            
            if let description = metric["description"] as? String {
                print(String(format: "  %-25s | %s", "Description", description))
            }
            
            if let typeValue = metric["type"] as? Int,
               let metricType = SNTMetricType(rawValue: typeValue) {
                let typeString = metricMakeStringFromMetricType(metricType)
                print(String(format: "  %-25s | %s", "Type", typeString))
            }
            
            if let fields = metric["fields"] as? [String: Any] {
                for (fieldName, fieldData) in fields {
                    if let fieldArray = fieldData as? [[String: Any]] {
                        for field in fieldArray {
                            if let created = field["created"] as? String {
                                print(String(format: "  %-25s | %s", "Created", created))
                            }
                            if let lastUpdated = field["last_updated"] as? String {
                                print(String(format: "  %-25s | %s", "Last Updated", lastUpdated))
                            }
                            if let data = field["data"] {
                                print(String(format: "  %-25s | %s", "Data", "\(data)"))
                            }
                            
                            // Handle field display
                            let fieldComponents = fieldName.split(separator: ",").map { String($0) }
                            if let fieldValues = field["value"] as? String {
                                let valueComponents = fieldValues.split(separator: ",").map { String($0) }
                                
                                if fieldComponents.count == valueComponents.count && !fieldComponents.isEmpty && !fieldComponents[0].isEmpty {
                                    var fieldDisplayString = ""
                                    for i in 0..<fieldComponents.count {
                                        fieldDisplayString += "\(fieldComponents[i])=\(valueComponents[i])"
                                        if i < fieldComponents.count - 1 {
                                            fieldDisplayString += ","
                                        }
                                    }
                                    print(String(format: "  %-25s | %s", "Field", fieldDisplayString))
                                }
                            }
                        }
                    }
                }
            }
            print()
        }
    }
    
    private func convertDatesToISO8601Strings(_ metrics: [String: Any]) -> [String: Any] {
        // Simplified version - in production would recursively convert Date objects
        return metrics
    }
    
    private func metricMakeStringFromMetricType(_ type: SNTMetricType) -> String {
        switch type {
        case .counter:
            return "counter"
        case .gauge:
            return "gauge"
        case .histogram:
            return "histogram"
        case .summary:
            return "summary"
        default:
            return "unknown"
        }
    }
    
    private func metricStringFromMetricFormatType(_ format: SNTMetricFormatType) -> String {
        switch format {
        case .raw:
            return "raw"
        case .json:
            return "json"
        default:
            return "unknown"
        }
    }
}

// MARK: - Placeholder Types

enum SNTMetricType: Int {
    case unknown = 0
    case counter = 1
    case gauge = 2
    case histogram = 3
    case summary = 4
}

enum SNTMetricFormatType: Int {
    case unknown = 0
    case raw = 1
    case json = 2
}

extension SNTConfigurator {
    var metricFormat: SNTMetricFormatType {
        return .json
    }
}

extension SNTDaemonControlXPC {
    func metrics(_ reply: @escaping ([String: Any]?) -> Void) {
        // Placeholder
        reply([:])
    }
}