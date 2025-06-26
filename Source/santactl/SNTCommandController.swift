import Foundation

/// Central controller that manages command registration and execution
@objc(SNTCommandController)
public class SNTCommandController: NSObject {
    /// Singleton instance
    @objc public static let shared = SNTCommandController()
    
    /// Registry of available commands
    private var commands: [String: SNTCommand.Type] = [:]
    
    /// XPC connection to the daemon
    private var xpcConnection: XPCConnection?
    
    override init() {
        super.init()
        registerCommands()
    }
    
    /// Register a command with the controller
    @objc public func registerCommand(_ commandClass: SNTCommand.Type, name: String) {
        commands[name] = commandClass
    }
    
    /// Execute a command with the given arguments
    public func execute(with arguments: [String]) async throws {
        // Handle empty arguments
        if arguments.isEmpty {
            printUsage()
            return
        }
        
        // Handle global help flag
        if arguments.count == 1 && (arguments[0] == "-h" || arguments[0] == "--help") {
            printUsage()
            return
        }
        
        if arguments.contains("-v") || arguments.contains("--version") {
            printVersion()
            return
        }
        
        // Get the command name
        guard let commandName = arguments.first else {
            printUsage()
            throw CommandError.noCommand
        }
        
        // Find the command
        guard let commandClass = commands[commandName] else {
            // Use FileHandle directly for error output
            let errorMessage = "Unknown command: \(commandName)\n"
            if let errorData = errorMessage.data(using: .utf8) {
                FileHandle.standardError.write(errorData)
            }
            printUsage()
            throw CommandError.unknownCommand(commandName)
        }
        
        // Create command instance
        let command = commandClass.init()
        
        // Check if command wants help
        let commandArgs = Array(arguments.dropFirst())
        if commandArgs.contains("-h") || commandArgs.contains("--help") {
            print(command.longHelp)
            return
        }
        
        // Set up daemon connection if needed
        if command.requiresDaemonConn {
            try await establishDaemonConnection()
            command.xpcConnection = xpcConnection
        }
        
        // Check root requirement
        if command.requiresRoot && getuid() != 0 {
            throw CommandError.requiresRoot
        }
        
        // Execute the command
        try await command.run(with: commandArgs)
    }
    
    /// Establish connection to the daemon
    private func establishDaemonConnection() async throws {
        guard xpcConnection == nil else { return }
        
        guard let connection = XPCConnection.createDaemonConnection() else {
            throw CommandError.xpcConnectionFailed
        }
        
        xpcConnection = connection
    }
    
    /// Print usage information
    private func printUsage() {
        print("""
        Usage: santactl <command> [options]
        
        Available commands:
        """)
        
        let sortedCommands = commands.keys.sorted()
        for commandName in sortedCommands {
            if let commandClass = commands[commandName] {
                let command = commandClass.init()
                print("  \(commandName.padding(toLength: 15, withPad: " ", startingAt: 0)) \(command.shortHelp)")
            }
        }
        
        print("""
        
        Options:
          -h, --help      Show this help message
          -v, --version   Show version information
        
        Use 'santactl <command> --help' for more information about a command.
        """)
    }
    
    /// Print version information
    private func printVersion() {
        // TODO: Get version from Info.plist
        print("santactl version 2025.1")
    }
    
    /// Register all available commands
    private func registerCommands() {
        // Commands will self-register using Swift's runtime features
        // For now, manually register commands
        registerCommand(SNTCommandStatus.self, name: "status")
        registerCommand(SNTCommandFileInfo.self, name: "fileinfo")
        registerCommand(SNTCommandRule.self, name: "rule")
        registerCommand(SNTCommandSync.self, name: "sync")
        registerCommand(SNTCommandVersion.self, name: "version")
        registerCommand(SNTCommandCheckCache.self, name: "checkcache")
        registerCommand(SNTCommandFlushCache.self, name: "flushcache")
        registerCommand(SNTCommandMetrics.self, name: "metrics")
        registerCommand(SNTCommandDoctor.self, name: "doctor")
        registerCommand(SNTCommandEventUpload.self, name: "eventupload")
        registerCommand(SNTCommandPrintLog.self, name: "printlog")
        registerCommand(SNTCommandInstall.self, name: "install")
        registerCommand(SNTCommandTelemetry.self, name: "telemetry")
        registerCommand(SNTCommandCompletion.self, name: "completion")
        
        // BundleInfo is only available in debug builds
        // Conditionally compiled based on build configuration
        registerCommand(SNTCommandBundleInfo.self, name: "bundleinfo")
    }
}

/// Errors that can occur during command execution
enum CommandError: LocalizedError {
    case noCommand
    case unknownCommand(String)
    case requiresRoot
    case xpcConnectionFailed
    case invalidArguments
    case invalidOperation
    
    var errorDescription: String? {
        switch self {
        case .noCommand:
            return "No command specified"
        case .unknownCommand(let name):
            return "Unknown command: \(name)"
        case .requiresRoot:
            return "This command requires root privileges"
        case .xpcConnectionFailed:
            return "Failed to connect to Santa daemon"
        case .invalidArguments:
            return "Invalid arguments provided"
        case .invalidOperation:
            return "Invalid operation"
        }
    }
}