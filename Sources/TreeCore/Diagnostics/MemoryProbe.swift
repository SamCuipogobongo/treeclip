import Foundation
import Darwin

/// Reads the process resident memory (RSS) via `task_info` — no Instruments,
/// no Xcode tooling required, so the memory gate runs in plain `swift test`/CI.
/// Used by the benchmark suite to assert treeclip's defining property: memory
/// does not scale with total payload bytes (the anti-Maccy invariant).
public enum MemoryProbe {
    public static func residentBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), raw, &count)
            }
        }
        return kr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
