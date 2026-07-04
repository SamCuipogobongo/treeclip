// swift-tools-version: 6.0
import PackageDescription

// treeclip — AI-agent-era macOS clipboard manager.
// Architecture: TreeCore (no UI, all business logic) <- TreeUI <- TreeApp.
// The layering is enforced by the target dependency graph: TreeCore must never
// depend on TreeUI/AppKit/SwiftUI, so "list UI never touches raw payload" is a
// compile-time guarantee, not a convention. See design.md §6.5.
let package = Package(
    name: "treeclip",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "TreeCore", targets: ["TreeCore"]),
        .library(name: "TreeUI", targets: ["TreeUI"]),
        .executable(name: "treeclip", targets: ["TreeApp"]),
    ],
    targets: [
        // Engine: storage / capture / paste routing / models. No UI imports.
        .target(name: "TreeCore"),
        // Interior trim: SwiftUI panels. Depends on TreeCore protocols only.
        .target(name: "TreeUI", dependencies: ["TreeCore"]),
        // Assembly: menu bar bootstrap, permission flow, wiring. Kept thin.
        .executableTarget(name: "TreeApp", dependencies: ["TreeCore", "TreeUI"]),

        .testTarget(name: "TreeCoreTests", dependencies: ["TreeCore"]),
        .testTarget(name: "TreeUITests", dependencies: ["TreeUI"]),
        // Quality gate: memory benchmarks become CI-required in M3.
        .testTarget(name: "TreeBenchmarks", dependencies: ["TreeCore"]),
    ]
)
