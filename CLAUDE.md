# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Santa is a high-performance security agent for macOS that provides binary and file access authorization. It consists of:
- A system extension that monitors executions and makes authorization decisions
- A GUI agent that notifies users about blocked executions
- A command-line utility (`santactl`) for management
- Background services for syncing rules and collecting metrics

## Development Commands

### Building
```bash
# Format code and build release (optimized)
make

# Build specific targets
bazel build -c opt //:release        # Build release package
bazel build //Source/santad:santad   # Build specific component
```

### Testing
```bash
# Run all unit tests
make test

# Run specific test target
bazel test //Source/santad:SNTExecutionControllerTest

# Run tests with specific output
bazel test --test_output=errors //:unit_tests
```

### Code Formatting and Linting
```bash
# Format all code (runs automatically with make)
make fmt

# This runs:
# - clang-format on .m, .h, .mm, .cc files
# - swift-format on Swift files  
# - buildifier on Bazel files
```

### Development Workflow
```bash
# Reload Santa components during development (requires SIP disabled)
make reload

# Generate compile_commands.json for IDE support
make compile_commands
```

### Cleaning
```bash
make clean      # Standard clean
make realclean  # Full expunge of Bazel cache
```

## Architecture Overview

### Core Components

1. **santad** (Source/santad/) - System extension daemon
   - Interfaces with Endpoint Security API for monitoring executions
   - Makes allow/block decisions based on rules
   - Manages execution cache for performance
   - Key classes: `SNTExecutionController`, `SNTRuleTable`, `SNTDecisionCache`

2. **Santa.app** (Source/gui/) - GUI application
   - Shows notifications for blocked executions
   - Manages system extension loading/unloading
   - Uses SwiftUI for modern UI components
   - Key components: `SNTNotificationManager`, `EventDetailView`

3. **santactl** (Source/santactl/) - Command-line interface
   - Rule management (add/remove)
   - System status and diagnostics
   - Sync with remote servers
   - Key commands: `rule`, `sync`, `status`, `fileinfo`

4. **Support Services**:
   - **santabundleservice** - Analyzes app bundles
   - **santametricservice** - Collects and exports metrics
   - **santasyncservice** - Manages rule synchronization

### Rule Evaluation Hierarchy

Rules are evaluated in order of specificity:
1. CDHash (specific binary hash)
2. Binary (SHA-256 hash)
3. SigningID 
4. Certificate (leaf certificate)
5. TeamID
6. CEL (Common Expression Language) policies

### Communication

- Components communicate via XPC (cross-process communication)
- All XPC connections validate peer certificates
- Message passing uses Protocol Buffers for some services

### Key Design Patterns

- **Event-driven architecture**: Responds to Endpoint Security events
- **Caching**: Execution decisions cached for performance
- **Fail-safe**: Cannot block system-critical binaries
- **Defense in depth**: Multiple rule types and evaluation levels

## Important Notes

- Development builds require SIP disabled for loading adhoc-signed system extensions
- All code must be properly signed for production deployment
- Use `SANTA_BUILD_TYPE=adhoc` for local development builds
- The project uses Bazel's MODULE.bazel for dependency management
- C++ code uses C++20 standard
- Objective-C++ files (.mm) mix C++ and Objective-C

## Common Development Tasks

### Adding a New Rule Type
1. Update proto definitions in Source/common/
2. Modify rule evaluation in SNTRuleTable
3. Add support in santactl commands
4. Update sync protocol if needed

### Debugging
- Use `santactl status` to check system state
- Logs available via Console.app (search for "santa")
- Enable verbose logging with `santactl debug`
- Use `santactl fileinfo <path>` to inspect binary signing info

### Performance Considerations
- Execution decisions must be fast (< 100ms)
- Use caching aggressively
- Avoid blocking I/O in critical paths
- Profile with Instruments when making changes to core paths