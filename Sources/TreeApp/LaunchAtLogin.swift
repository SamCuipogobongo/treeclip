import Foundation
import ServiceManagement

/// Register/unregister the app as a login item via SMAppService. Requires a real
/// bundle (make-app.sh provides one). Silent on failure — it's a convenience,
/// not a critical path.
enum LaunchAtLogin {
    static func apply(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
        } catch {
            NSLog("treeclip: launch-at-login \(enabled ? "register" : "unregister") failed: \(error)")
        }
    }
}
