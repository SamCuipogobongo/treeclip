import Testing
@testable import TreeCore

/// Memory benchmark gate. In M3 this becomes a CI-required check enforcing the
/// PRD acceptance numbers (3000-item warm idle < 100MB; +100 4K images ≈
/// thumbnail bytes only; RSS drops after clear). See implement.md M3.
///
/// M0 skeleton: placeholder so the gate target exists in the four-package
/// structure from day 1. Real fixtures + footprint assertions land in M3.
@Suite struct MemoryBenchmarkTests {
    @Test(.disabled("Memory benchmarks land in M3 (needs TreeCore.Store fixtures)."))
    func gatePlaceholder() {}
}
