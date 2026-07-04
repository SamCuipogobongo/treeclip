import AppKit
import TreeCore
import TreeCapture

// M2 smoke harness (not the real app — the menu bar bootstrap lands in M7).
// Runs the capture pipeline headlessly against the real system clipboard and
// prints each captured item, so `swift run treeclip` is a live manual check:
// copy text/images in other apps and watch them get captured + stored.
//
// Storage goes to the standard location; press Ctrl-C to stop.
@MainActor
func runCaptureSmoke() throws {
    let store = try Store(location: try .standard())
    let driver = CaptureDriver(store: store)
    driver.onCapture = { id, label in
        print("captured [\(id.prefix(8))] \(label)")
        fflush(stdout)                          // line-flush even when redirected
    }
    driver.start()
    print("treeclip \(TreeCore.version) — capture smoke running. Copy something; Ctrl-C to quit.")
    fflush(stdout)
    RunLoop.main.run()
}

try MainActor.assumeIsolated { try runCaptureSmoke() }
