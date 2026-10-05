import Cocoa

// Pelíšek: ikona v Docku. Po kliknutí pošle Julii signál (jdi spát / vstávej) i s polohou kurzoru,
// ať Julie ví, kde ikona je. Když Julie neběží, nejdřív ji spustí. Pak se hned ukončí.

_ = NSApplication.shared
let mouse = NSEvent.mouseLocation
let julieID = "cz.karelhlas.julie"

func signal() {
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("cz.karelhlas.julie.pelisek"), object: nil,
        userInfo: ["x": Double(mouse.x), "y": Double(mouse.y)], deliverImmediately: true)
}

if NSRunningApplication.runningApplications(withBundleIdentifier: julieID).isEmpty {
    let julie = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Julie.app")
    NSWorkspace.shared.openApplication(at: julie, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    RunLoop.main.run(until: Date().addingTimeInterval(2.5))
}
signal()
RunLoop.main.run(until: Date().addingTimeInterval(0.3))
exit(0)
