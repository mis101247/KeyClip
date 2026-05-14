import AppKit

enum AppIconLoader {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleID bundleID: String) -> NSImage? {
        if let cached = cache.object(forKey: bundleID as NSString) {
            return cached
        }

        let icon: NSImage?
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
           let runningIcon = running.icon {
            icon = runningIcon
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = nil
        }

        if let icon {
            cache.setObject(icon, forKey: bundleID as NSString)
        }

        return icon
    }
}
