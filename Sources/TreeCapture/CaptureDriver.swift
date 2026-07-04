import AppKit
import TreeCore

/// Drives capture: polls the pasteboard's `changeCount` and, on change, runs the
/// snapshot through the coordinator and into the store. `@MainActor` because it
/// touches AppKit and a main-runloop timer; the heavy lifting is in the UI-free
/// coordinator/store. Ownership: pastes we perform ourselves (M5) will bump
/// `suppressChangeCount` so we don't re-capture our own writes.
@MainActor
public final class CaptureDriver {
    private let source: PasteboardSource
    private let coordinator: CaptureCoordinator
    private let store: Store
    private let interval: TimeInterval
    private var lastChangeCount: Int
    private var timer: Timer?

    /// Called after each successful capture (id + a short label). Optional hook
    /// for the M2 smoke harness / future UI.
    public var onCapture: (@MainActor (String, String) -> Void)?

    public init(
        store: Store,
        source: PasteboardSource = SystemPasteboardSource(),
        coordinator: CaptureCoordinator = CaptureCoordinator(),
        interval: TimeInterval = 0.5
    ) {
        self.store = store
        self.source = source
        self.coordinator = coordinator
        self.interval = interval
        self.lastChangeCount = source.changeCount
    }

    public func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let cc = source.changeCount
        guard cc != lastChangeCount else { return }
        lastChangeCount = cc
        guard let snapshot = source.snapshot(),
              let item = coordinator.process(snapshot) else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let label = "\(item.kind): \(item.title.prefix(48))"
        let store = self.store
        let onCapture = self.onCapture
        Task {
            if let id = try? await store.ingest(item, nowMillis: now) {
                await MainActor.run { onCapture?(id, label) }
            }
        }
    }
}
