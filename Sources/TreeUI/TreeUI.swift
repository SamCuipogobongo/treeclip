import TreeCore

/// treeclip UI namespace: SwiftUI panels (palette, floating notes) that render
/// TreeCore state. TreeUI may depend on TreeCore, never the reverse.
///
/// M0 skeleton — PalettePanel lands in M4, NotePanels in M6.
public enum TreeUI {
    /// The engine version this UI is built against.
    public static let coreVersion = TreeCore.version
}
