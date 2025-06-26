import Foundation
import ArgumentParser

// Example of how to use ArgumentParser with santactl
// This is an alternative main.swift that uses ArgumentParser

@main
struct SantaCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "santactl",
        abstract: "Manage Santa, a macOS binary authorization system",
        version: "2025.1",
        subcommands: [
            StatusCommand.self,
            VersionCommand.self,
            FileInfoCommand.self,
            // Add more commands here
        ]
    )
}

// Example: Status command with ArgumentParser
struct StatusCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show Santa status information"
    )
    
    @Flag(name: .shortAndLong, help: "Output in JSON format")
    var json = false
    
    mutating func run() async throws {
        // Use the existing SNTCommandStatus
        let statusCmd = SNTCommandStatus()
        let args = json ? ["--json"] : []
        try await statusCmd.run(with: args)
    }
}

// Example: Version command with ArgumentParser
struct VersionCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Show Santa component versions"
    )
    
    mutating func run() async throws {
        let versionCmd = SNTCommandVersion()
        try await versionCmd.run(with: [])
    }
}

// Example: FileInfo command with ArgumentParser
struct FileInfoCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fileinfo",
        abstract: "Prints information about files"
    )
    
    @Argument(help: "Paths to files to inspect")
    var paths: [String] = []
    
    @Flag(name: .shortAndLong, help: "Output in JSON format")
    var json = false
    
    @Flag(name: .shortAndLong, help: "Search directories recursively")
    var recursive = false
    
    @Option(name: .shortAndLong, help: "Search and return specific information")
    var key: [String] = []
    
    mutating func run() async throws {
        var args: [String] = []
        
        if json {
            args.append("--json")
        }
        
        if recursive {
            args.append("--recursive")
        }
        
        for k in key {
            args.append("--key")
            args.append(k)
        }
        
        args.append(contentsOf: paths)
        
        let fileInfoCmd = SNTCommandFileInfo()
        try await fileInfoCmd.run(with: args)
    }
}