import Foundation

/// Shell completion script generator for santactl
/// This provides shell completion support similar to swift-argument-parser
struct CompletionScripts {
    
    /// Generate bash completion script
    static func bashCompletionScript() -> String {
        return """
        _santactl_completion() {
            local cur prev commands
            COMPREPLY=()
            cur="${COMP_WORDS[COMP_CWORD]}"
            prev="${COMP_WORDS[COMP_CWORD-1]}"
            
            # Main commands
            commands="status version rule sync fileinfo checkcache flushcache metrics doctor eventupload printlog install telemetry bundleinfo help"
            
            # If we're on the first argument, complete commands
            if [ $COMP_CWORD -eq 1 ]; then
                COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
                return 0
            fi
            
            # Command-specific completions
            case "${COMP_WORDS[1]}" in
                rule)
                    if [ $COMP_CWORD -eq 2 ]; then
                        COMPREPLY=( $(compgen -W "add remove list" -- "$cur") )
                    elif [ "${COMP_WORDS[2]}" = "add" ]; then
                        COMPREPLY=( $(compgen -W "--path --sha256 --certificate --teamID --signingID --state --message" -- "$cur") )
                    fi
                    ;;
                fileinfo|checkcache|bundleinfo)
                    # File path completion
                    COMPREPLY=( $(compgen -f -- "$cur") )
                    ;;
                status|version|sync|metrics)
                    COMPREPLY=( $(compgen -W "--json" -- "$cur") )
                    ;;
                printlog)
                    COMPREPLY=( $(compgen -W "--path --format" -- "$cur") )
                    ;;
                install)
                    COMPREPLY=( $(compgen -W "--force" -- "$cur") )
                    ;;
                *)
                    # General options
                    COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
                    ;;
            esac
        }
        
        complete -F _santactl_completion santactl
        """
    }
    
    /// Generate zsh completion script
    static func zshCompletionScript() -> String {
        return """
        #compdef santactl
        
        _santactl() {
            local -a commands
            commands=(
                'status:Show Santa status information'
                'version:Show Santa component versions'
                'rule:Manage rules'
                'sync:Sync with server'
                'fileinfo:Inspect file information'
                'checkcache:Check file in cache'
                'flushcache:Flush decision cache'
                'metrics:Display metrics'
                'doctor:Run system diagnostics'
                'eventupload:Upload blocked events'
                'printlog:Print Santa logs'
                'install:Install Santa components'
                'telemetry:Telemetry operations'
                'bundleinfo:Analyze app bundles'
                'help:Show help information'
            )
            
            _arguments -C \\
                '1: :->command' \\
                '*::arg:->args'
            
            case $state in
                command)
                    _describe 'santactl command' commands
                    ;;
                args)
                    case $words[1] in
                        rule)
                            local -a rule_commands
                            rule_commands=(
                                'add:Add a rule'
                                'remove:Remove a rule'
                                'list:List rules'
                            )
                            _arguments -C \\
                                '1: :->rule_command' \\
                                '*::arg:->rule_args'
                            
                            case $state in
                                rule_command)
                                    _describe 'rule command' rule_commands
                                    ;;
                                rule_args)
                                    case $words[1] in
                                        add)
                                            _arguments \\
                                                '--path[Path to the file]:file:_files' \\
                                                '--sha256[SHA256 hash]:hash:' \\
                                                '--certificate[Certificate SHA256]:cert:' \\
                                                '--teamID[Team ID]:teamid:' \\
                                                '--signingID[Signing ID]:signingid:' \\
                                                '--state[Rule state]:state:(ALLOWLIST BLOCKLIST)' \\
                                                '--message[Custom message]:message:'
                                            ;;
                                    esac
                                    ;;
                            esac
                            ;;
                        fileinfo|checkcache|bundleinfo)
                            _files
                            ;;
                        status|version|sync|metrics)
                            _arguments '--json[Output in JSON format]'
                            ;;
                        printlog)
                            _arguments \\
                                '--path[Log file path]:file:_files' \\
                                '--format[Output format]:format:(syslog json)'
                            ;;
                        install)
                            _arguments '--force[Force reinstall]'
                            ;;
                    esac
                    ;;
            esac
        }
        
        _santactl "$@"
        """
    }
    
    /// Generate fish completion script
    static func fishCompletionScript() -> String {
        return """
        # Completions for santactl
        
        # Disable file completions by default
        complete -c santactl -f
        
        # Main commands
        complete -c santactl -n '__fish_use_subcommand' -a status -d 'Show Santa status information'
        complete -c santactl -n '__fish_use_subcommand' -a version -d 'Show Santa component versions'
        complete -c santactl -n '__fish_use_subcommand' -a rule -d 'Manage rules'
        complete -c santactl -n '__fish_use_subcommand' -a sync -d 'Sync with server'
        complete -c santactl -n '__fish_use_subcommand' -a fileinfo -d 'Inspect file information'
        complete -c santactl -n '__fish_use_subcommand' -a checkcache -d 'Check file in cache'
        complete -c santactl -n '__fish_use_subcommand' -a flushcache -d 'Flush decision cache'
        complete -c santactl -n '__fish_use_subcommand' -a metrics -d 'Display metrics'
        complete -c santactl -n '__fish_use_subcommand' -a doctor -d 'Run system diagnostics'
        complete -c santactl -n '__fish_use_subcommand' -a eventupload -d 'Upload blocked events'
        complete -c santactl -n '__fish_use_subcommand' -a printlog -d 'Print Santa logs'
        complete -c santactl -n '__fish_use_subcommand' -a install -d 'Install Santa components'
        complete -c santactl -n '__fish_use_subcommand' -a telemetry -d 'Telemetry operations'
        complete -c santactl -n '__fish_use_subcommand' -a bundleinfo -d 'Analyze app bundles'
        complete -c santactl -n '__fish_use_subcommand' -a help -d 'Show help information'
        
        # Rule subcommands
        complete -c santactl -n '__fish_seen_subcommand_from rule; and not __fish_seen_subcommand_from add remove list' -a add -d 'Add a rule'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and not __fish_seen_subcommand_from add remove list' -a remove -d 'Remove a rule'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and not __fish_seen_subcommand_from add remove list' -a list -d 'List rules'
        
        # Rule add options
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l path -d 'Path to the file' -r
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l sha256 -d 'SHA256 hash'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l certificate -d 'Certificate SHA256'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l teamID -d 'Team ID'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l signingID -d 'Signing ID'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l state -d 'Rule state' -a 'ALLOWLIST BLOCKLIST'
        complete -c santactl -n '__fish_seen_subcommand_from rule; and __fish_seen_subcommand_from add' -l message -d 'Custom message'
        
        # File completions for specific commands
        complete -c santactl -n '__fish_seen_subcommand_from fileinfo checkcache bundleinfo' -F
        
        # JSON flag for applicable commands
        complete -c santactl -n '__fish_seen_subcommand_from status version sync metrics' -l json -d 'Output in JSON format'
        
        # Other command-specific options
        complete -c santactl -n '__fish_seen_subcommand_from printlog' -l path -d 'Log file path' -r
        complete -c santactl -n '__fish_seen_subcommand_from printlog' -l format -d 'Output format' -a 'syslog json'
        complete -c santactl -n '__fish_seen_subcommand_from install' -l force -d 'Force reinstall'
        """
    }
    
    /// Install completion script for the specified shell
    static func installCompletionScript(for shell: String) throws {
        let script: String
        let installPath: String
        
        switch shell.lowercased() {
        case "bash":
            script = bashCompletionScript()
            if let brewPrefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] {
                installPath = "\(brewPrefix)/etc/bash_completion.d/santactl"
            } else {
                installPath = "/usr/local/etc/bash_completion.d/santactl"
            }
            
        case "zsh":
            script = zshCompletionScript()
            // Check common zsh completion directories
            let zshDirs = [
                "/usr/local/share/zsh/site-functions",
                "/opt/homebrew/share/zsh/site-functions",
                "/usr/share/zsh/site-functions"
            ]
            if let dir = zshDirs.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                installPath = "\(dir)/_santactl"
            } else {
                installPath = "/usr/local/share/zsh/site-functions/_santactl"
            }
            
        case "fish":
            script = fishCompletionScript()
            if let configHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
                installPath = "\(configHome)/fish/completions/santactl.fish"
            } else if let home = ProcessInfo.processInfo.environment["HOME"] {
                installPath = "\(home)/.config/fish/completions/santactl.fish"
            } else {
                installPath = "/usr/local/share/fish/completions/santactl.fish"
            }
            
        default:
            throw CompletionError.unsupportedShell(shell)
        }
        
        print("Installing \(shell) completion script to: \(installPath)")
        
        // Create directory if needed
        let directory = URL(fileURLWithPath: installPath).deletingLastPathComponent().path
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        
        // Write the script
        try script.write(toFile: installPath, atomically: true, encoding: .utf8)
        
        print("Completion script installed successfully!")
        print("You may need to restart your shell or run:")
        switch shell.lowercased() {
        case "bash":
            print("  source \(installPath)")
        case "zsh":
            print("  autoload -U compinit && compinit")
        case "fish":
            print("  source \(installPath)")
        default:
            break
        }
    }
    
    /// Print completion script for the specified shell
    static func printCompletionScript(for shell: String) throws {
        let script: String
        
        switch shell.lowercased() {
        case "bash":
            script = bashCompletionScript()
        case "zsh":
            script = zshCompletionScript()
        case "fish":
            script = fishCompletionScript()
        default:
            throw CompletionError.unsupportedShell(shell)
        }
        
        print(script)
    }
}

enum CompletionError: LocalizedError {
    case unsupportedShell(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedShell(let shell):
            return "Unsupported shell: \(shell). Supported shells are: bash, zsh, fish"
        }
    }
}