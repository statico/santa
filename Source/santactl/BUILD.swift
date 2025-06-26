load("@rules_apple//apple:macos.bzl", "macos_command_line_application")
load("@rules_swift//swift:swift.bzl", "swift_library")

licenses(["notice"])

# Minimal Swift implementation for testing
swift_library(
    name = "santactl_swift_minimal",
    srcs = [
        "main.swift",
        "SNTCommand.swift", 
        "SNTCommandController.swift",
        "Commands/SNTCommandSimpleVersion.swift",
    ],
    module_name = "SantaCtl",
)

# Swift-based santactl binary
macos_command_line_application(
    name = "santactl_swift",
    bundle_id = "com.northpolesec.santa.ctl.swift",
    minimum_os_version = "13.0",
    visibility = ["//:santa_package_group"],
    deps = [":santactl_swift_minimal"],
)