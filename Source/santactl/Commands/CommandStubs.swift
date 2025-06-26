import Foundation

// Stub implementations for commands that are not yet implemented in Swift
// These will be replaced with proper implementations later

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

