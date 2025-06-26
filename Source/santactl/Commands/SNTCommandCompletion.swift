import Foundation

/// Generate shell completion scripts
@objc(SNTCommandCompletion)
class SNTCommandCompletion: SNTCommand {
    override var shortHelp: String {
        return "Generate shell completion scripts"
    }
    
    override var longHelp: String {
        return """
        Generate shell completion scripts for santactl.
        
        Usage:
          santactl completion --shell <shell>
          santactl completion --shell <shell> --install
        
        Options:
          --shell <shell>    Shell type (bash, zsh, fish)
          --install          Install the completion script to the appropriate location
        
        Examples:
          # Generate bash completion script
          santactl completion --shell bash
          
          # Install zsh completion
          santactl completion --shell zsh --install
          
          # Save fish completion to a file
          santactl completion --shell fish > ~/.config/fish/completions/santactl.fish
        """
    }
    
    override var requiresRoot: Bool {
        return false
    }
    
    override var requiresDaemonConn: Bool {
        return false
    }
    
    override func run(with arguments: [String]) async throws {
        let options = try parseArguments(arguments)
        
        guard let shell = options["shell"] as? String else {
            printError("Missing required option: --shell")
            print(longHelp)
            throw CommandError.invalidArguments
        }
        
        let shouldInstall = options["install"] as? Bool ?? false
        
        do {
            if shouldInstall {
                try CompletionScripts.installCompletionScript(for: shell)
            } else {
                try CompletionScripts.printCompletionScript(for: shell)
            }
        } catch {
            printError(error.localizedDescription)
            throw error
        }
    }
    
    override func parseArguments(_ arguments: [String]) throws -> [String: Any] {
        var options = try super.parseArguments(arguments)
        
        // Handle --shell option specially
        for i in 0..<arguments.count {
            if arguments[i] == "--shell" && i + 1 < arguments.count {
                options["shell"] = arguments[i + 1]
            }
        }
        
        return options
    }
}

// Use the CommandError from SNTCommandController