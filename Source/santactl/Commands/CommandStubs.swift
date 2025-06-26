import Foundation

// Stub implementations for commands that are not yet implemented in Swift
// These will be replaced with proper implementations later

@objc(SNTCommandFileInfo)
class SNTCommandFileInfo: SNTCommand {
    override var shortHelp: String {
        return "Show code-signing information about a file."
    }
}

@objc(SNTCommandRule)
class SNTCommandRule: SNTCommand {
    override var shortHelp: String {
        return "Manage rules."
    }
}

@objc(SNTCommandSync)
class SNTCommandSync: SNTCommand {
    override var shortHelp: String {
        return "Synchronize with a configured server."
    }
}

@objc(SNTCommandCheckCache)
class SNTCommandCheckCache: SNTCommand {
    override var shortHelp: String {
        return "Check cache for a file."
    }
}

@objc(SNTCommandFlushCache)
class SNTCommandFlushCache: SNTCommand {
    override var shortHelp: String {
        return "Flush decision cache."
    }
}

@objc(SNTCommandMetrics)
class SNTCommandMetrics: SNTCommand {
    override var shortHelp: String {
        return "Show Santa metrics."
    }
}

@objc(SNTCommandDoctor)
class SNTCommandDoctor: SNTCommand {
    override var shortHelp: String {
        return "Run system diagnostics."
    }
}

@objc(SNTCommandEventUpload)
class SNTCommandEventUpload: SNTCommand {
    override var shortHelp: String {
        return "Upload blocked execution events."
    }
}

@objc(SNTCommandPrintLog)
class SNTCommandPrintLog: SNTCommand {
    override var shortHelp: String {
        return "Print logs from a Santa log file."
    }
}

@objc(SNTCommandInstall)
class SNTCommandInstall: SNTCommand {
    override var shortHelp: String {
        return "Install Santa system extension."
    }
}

@objc(SNTCommandTelemetry)
class SNTCommandTelemetry: SNTCommand {
    override var shortHelp: String {
        return "Telemetry operations."
    }
}

@objc(SNTCommandBundleInfo)
class SNTCommandBundleInfo: SNTCommand {
    override var shortHelp: String {
        return "Analyze application bundles."
    }
}