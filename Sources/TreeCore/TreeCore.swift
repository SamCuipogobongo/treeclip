import Foundation

/// treeclip engine namespace. All business logic (storage, capture, paste
/// routing, models) lives under TreeCore and carries no UI dependency.
///
/// M0 is a skeleton: real subsystems land in M1 (Store) / M2 (Capture) /
/// M5 (PasteEngine). This placeholder exists so the four-package structure
/// and the compile-time layering boundary are in place from the first commit.
public enum TreeCore {
    /// Semantic version of the engine. Bumped as milestones land.
    public static let version = "0.0.0"
}
