import TreeCore
import TreeUI

// Assembly layer. Kept deliberately thin: no business branching here — that is
// an anti-pattern signal (see design.md §6.5). The real menu bar bootstrap
// (LSUIElement, NSStatusItem, just-in-time Accessibility flow) lands in M7.
//
// M0 skeleton: prove the executable links TreeCore + TreeUI and runs.
print("treeclip \(TreeCore.version) — core=\(TreeUI.coreVersion)")
