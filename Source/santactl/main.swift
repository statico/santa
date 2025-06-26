import Foundation

// Main entry point for santactl
// Create the command controller
let controller = SNTCommandController()

// Parse command line arguments
let arguments = ProcessInfo.processInfo.arguments

// Remove the program name from arguments
let args = Array(arguments.dropFirst())

// Execute the command
Task {
    do {
        try await controller.execute(with: args)
        exit(0)
    } catch {
        // Print error directly to stderr
        let errorMessage = "Error: \(error.localizedDescription)\n"
        if let errorData = errorMessage.data(using: .utf8) {
            FileHandle.standardError.write(errorData)
        }
        exit(1)
    }
}

// Keep the run loop alive for async operations
RunLoop.main.run()