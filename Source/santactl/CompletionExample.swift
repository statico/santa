import Foundation
import ArgumentParser

// Example demonstrating ArgumentParser's built-in completion script generation

struct CompletionExample: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "santactl-ap",
        abstract: "Example of ArgumentParser with completion support",
        subcommands: [GenerateCompletion.self]
    )
}

struct GenerateCompletion: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-completion",
        abstract: "Generate shell completion scripts using ArgumentParser"
    )
    
    @Option(help: "Shell type to generate completions for")
    var shell: CompletionShell
    
    func run() throws {
        // ArgumentParser provides built-in completion generation
        // When installed, users can run:
        // santactl --generate-completion-script bash
        // santactl --generate-completion-script zsh
        // santactl --generate-completion-script fish
        
        print("To generate completion scripts with ArgumentParser, run:")
        print("  santactl --generate-completion-script \(shell)")
        print("")
        print("Then source the output in your shell configuration.")
    }
}

enum CompletionShell: String, ExpressibleByArgument, CaseIterable {
    case bash
    case zsh
    case fish
}