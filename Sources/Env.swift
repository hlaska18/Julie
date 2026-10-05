import Cocoa

struct WinInfo {
    var id: Int
    var frame: CGRect      // souřadnice Cocoa (počátek vlevo dole na hlavní obrazovce)
    var top: CGFloat { frame.maxY }
}

/// Obrazovka a okna ostatních aplikací (bez oprávnění stačí obdélníky oken).
final class Env {
    var screen: NSScreen
    var left: CGFloat = 0
    var right: CGFloat = 1440
    var floorY: CGFloat = 0
    var ceilY: CGFloat = 900
    var windows: [WinInfo] = []     // od předního po zadní
    private var lastRefresh: TimeInterval = 0
    var dockL: CGFloat = 0          // úsek Docku, po kterém smí Julie chodit
    var dockR: CGFloat = 1440
    var dockWidthOverride: CGFloat = 0
    var dockExact = false           // změřeno přes přístupnost (jinak odhad)
    var bedXEstimate: CGFloat?      // odhad, kde je v Docku ikona Pelíšek
    var fullscreen = false          // aktivní plocha je aplikace na celé obrazovce (Dock schovaný)
    var followFullscreen = false    // má Julie na celé obrazovce chodit po spodním okraji (jinak je schovaná)
    var dockAvailable = true        // Dock je dole na hlavní obrazovce a není schovaný
    private var fullByWindow = false

    init() {
        screen = NSScreen.screens.first ?? NSScreen.main!
        refreshScreen()
        refreshDock()
    }

    func refreshScreen() {
        screen = NSScreen.screens.first ?? screen
        let f = screen.frame
        left = f.minX
        right = f.maxX
        applyFloor()
    }

    func window(_ id: Int) -> WinInfo? {
        windows.first { $0.id == id }
    }

    func refreshWindows(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        if !force && now - lastRefresh < 0.15 { return }
        lastRefresh = now
        let pid = ProcessInfo.processInfo.processIdentifier
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let primaryH = screen.frame.height
        var out: [WinInfo] = []
        var fullByWindow = false
        for d in list {
            // záloha: okno přes celou šířku až dolů, nahoře nejvýš pod výřezem/lištou (MacBook s výřezem: 1710×1073)
            if let layer = d[kCGWindowLayer as String] as? Int, layer == 0,
               let bd = d[kCGWindowBounds as String] as? [String: CGFloat],
               let r = CGRect(dictionaryRepresentation: bd as CFDictionary),
               abs(r.width - screen.frame.width) < 2, r.minY <= 40, abs(r.maxY - screen.frame.height) < 2,
               r.height > screen.frame.height - 60 {
                fullByWindow = true
            }
            guard let layer = d[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            if let owner = d[kCGWindowOwnerPID as String] as? Int32, owner == pid { continue }
            if let alpha = d[kCGWindowAlpha as String] as? Double, alpha < 0.1 { continue }
            guard let bd = d[kCGWindowBounds as String] as? [String: CGFloat],
                  let r = CGRect(dictionaryRepresentation: bd as CFDictionary),
                  let num = d[kCGWindowNumber as String] as? Int else { continue }
            if r.width < 220 || r.height < 110 { continue }
            let cocoa = CGRect(x: r.minX, y: primaryH - r.maxY, width: r.width, height: r.height)
            // celoobrazovková okna nemají na čem stát
            if cocoa.height > screen.frame.height - 60 { continue }
            if cocoa.maxY > ceilY - 40 { continue }
            if cocoa.maxY < floorY + 50 { continue }
            out.append(WinInfo(id: num, frame: cocoa))
        }
        windows = out
        self.fullByWindow = fullByWindow
    }

    /// Je teď aktivní plocha aplikace na celé obrazovce? (levně přes typ plochy, záložně podle oken)
    func refreshFullscreen() {
        var full: Bool
        if let f = Env.activeSpaceIsFullscreen() { full = f } else { refreshWindows(force: true); full = fullByWindow }
        if full != fullscreen {
            fullscreen = full
            applyFloor()
        }
    }

    /// Zrcadlí se hlavní obrazovka (projektor, AirPlay)?
    static func mainDisplayMirrored() -> Bool {
        let main = CGMainDisplayID()
        if CGDisplayIsInMirrorSet(main) != 0 { return true }
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &n) == .success else { return false }
        return ids.prefix(Int(n)).contains { $0 != main && CGDisplayMirrorsDisplay($0) == main }
    }

    /// Je hlavní obrazovka (s lištou) externí, zatímco vestavěný displej MacBooku je zapnutý? (typicky projektor)
    static func mainIsExternalWhileBuiltinOn() -> Bool {
        let main = CGMainDisplayID()
        if CGDisplayIsBuiltin(main) != 0 { return false }
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var n: UInt32 = 0
        guard CGGetOnlineDisplayList(16, &ids, &n) == .success else { return false }
        return ids.prefix(Int(n)).contains { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsActive($0) != 0 }
    }

    /// Na celé obrazovce je Dock schovaný: Julie chodí po spodním okraji obrazovky.
    func applyFloor() {
        // když je Julie na celé obrazovce schovaná, zem se nemění: po návratu je tam, kde byla
        let full = fullscreen && followFullscreen
        floorY = full ? screen.frame.minY : screen.visibleFrame.minY
        ceilY = full ? screen.frame.maxY : screen.visibleFrame.maxY
    }

    /// Je bod (x, y) zakrytý nějakým oknem, které je v pořadí před oknem `id`?
    func covered(x: CGFloat, y: CGFloat, below id: Int) -> Bool {
        for w in windows {
            if w.id == id { return false }
            if w.frame.insetBy(dx: 0, dy: 0).contains(CGPoint(x: x, y: y - 2)) { return true }
        }
        return false
    }
}

// MARK: plocha na celé obrazovce

extension Env {
    private typealias MainConnFn = @convention(c) () -> Int32
    private typealias CopySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private static let cgs: (MainConnFn, CopySpacesFn)? = {
        guard let h = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY),
              let a = dlsym(h, "CGSMainConnectionID"), let b = dlsym(h, "CGSCopyManagedDisplaySpaces") else { return nil }
        return (unsafeBitCast(a, to: MainConnFn.self), unsafeBitCast(b, to: CopySpacesFn.self))
    }()

    /// Je na hlavním displeji právě plocha aplikace na celé obrazovce? (typ plochy 4)
    /// Neveřejné rozhraní macOS; když není k dispozici, vrací nil a použije se kontrola oken.
    static func activeSpaceIsFullscreen() -> Bool? {
        guard let (conn, copy) = cgs,
              let arr = copy(conn())?.takeRetainedValue() as? [[String: Any]] else { return nil }
        let main = CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(CGMainDisplayID()).takeRetainedValue()) as String
        let disp = arr.first { ($0["Display Identifier"] as? String) == main } ?? arr.first { ($0["Display Identifier"] as? String) == "Main" } ?? arr.first
        guard let cur = disp?["Current Space"] as? [String: Any], let type = cur["type"] as? Int else { return nil }
        return type == 4
    }
}

// MARK: Dock

extension Env {
    private func dockPref(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString)
    }

    /// Přesná poloha seznamu ikon Docku (potřebuje oprávnění Zpřístupnění), jinak nil.
    private func dockRectAX() -> (CGFloat, CGFloat)? {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let el = AXUIElementCreateApplication(app.processIdentifier)
        var ch: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ch) == .success,
              let arr = ch as? [AXUIElement] else { return nil }
        for c in arr {
            var pos: CFTypeRef?, size: CFTypeRef?
            AXUIElementCopyAttributeValue(c, kAXPositionAttribute as CFString, &pos)
            AXUIElementCopyAttributeValue(c, kAXSizeAttribute as CFString, &size)
            var p = CGPoint.zero, sz = CGSize.zero
            if let pv = pos, let sv = size,
               AXValueGetValue(pv as! AXValue, .cgPoint, &p), AXValueGetValue(sv as! AXValue, .cgSize, &sz),
               sz.width > 100 {
                return (p.x, p.x + sz.width)
            }
        }
        return nil
    }

    private func isBedTile(_ a: [String: Any]) -> Bool {
        guard let td = a["tile-data"] as? [String: Any] else { return false }
        if (td["bundle-identifier"] as? String) == "cz.karelhlas.julie.pelisek" { return true }
        let url = ((td["file-data"] as? [String: Any])?["_CFURLString"] as? String) ?? ""
        let u = url.removingPercentEncoding ?? url
        return u.contains("Pelíšek.app")
    }

    /// Poloha ikony Pelíšek přes Zpřístupnění (přesně), jinak nil.
    private func bedXAX() -> CGFloat? {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let el = AXUIElementCreateApplication(app.processIdentifier)
        var ch: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ch) == .success,
              let lists = ch as? [AXUIElement] else { return nil }
        for l in lists {
            var items: CFTypeRef?
            guard AXUIElementCopyAttributeValue(l, kAXChildrenAttribute as CFString, &items) == .success,
                  let arr = items as? [AXUIElement] else { continue }
            for it in arr {
                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(it, kAXTitleAttribute as CFString, &title)
                guard (title as? String) == "Pelíšek" else { continue }
                var pos: CFTypeRef?, size: CFTypeRef?
                AXUIElementCopyAttributeValue(it, kAXPositionAttribute as CFString, &pos)
                AXUIElementCopyAttributeValue(it, kAXSizeAttribute as CFString, &size)
                var p = CGPoint.zero, sz = CGSize.zero
                if let pv = pos, let sv = size, AXValueGetValue(pv as! AXValue, .cgPoint, &p), AXValueGetValue(sv as! AXValue, .cgSize, &sz) {
                    return p.x + sz.width / 2
                }
            }
        }
        return nil
    }

    func refreshDock() {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        let f = screen.frame, v = screen.visibleFrame
        let orient = (dockPref("orientation") as? String) ?? "bottom"
        let auto = (dockPref("autohide") as? Bool) ?? false
        // Dock vlevo/vpravo, schovaný nebo na jiném monitoru: Julie nemá kde chodit → schová se
        dockAvailable = orient == "bottom" && !auto && v.minY - f.minY > 20
        guard dockAvailable else {
            dockL = f.minX + 60; dockR = f.maxX - 60; dockExact = false
            return
        }
        let mid = f.midX
        if dockWidthOverride > 0 {
            dockL = mid - dockWidthOverride / 2; dockR = mid + dockWidthOverride / 2; dockExact = false
            return
        }
        if let (l, r) = dockRectAX() {
            dockL = l + 6; dockR = r - 6; dockExact = true
            bedXEstimate = bedXAX()
            return
        }
        // odhad z nastavení Docku (schválně spíš užší, aby Julie nikdy nepřešla hranu)
        let tile = CGFloat((dockPref("tilesize") as? NSNumber)?.doubleValue ?? 48)
        let apps = (dockPref("persistent-apps") as? [[String: Any]]) ?? []
        var icons = 1 + 1     // Finder + koš
        var spacers: CGFloat = 0
        var slot: CGFloat = 1 // Finder je první
        var bedSlot: CGFloat?
        var pinned = Set<String>()
        for a in apps {
            let t = (a["tile-type"] as? String) ?? ""
            if isBedTile(a) { bedSlot = slot }
            if let id = (a["tile-data"] as? [String: Any])?["bundle-identifier"] as? String { pinned.insert(id) }
            if t.contains("spacer") { let w: CGFloat = t.hasPrefix("small") ? 0.5 : 1; spacers += w; slot += w } else { icons += 1; slot += 1 }
        }
        let others = (dockPref("persistent-others") as? [Any])?.count ?? 0
        // pravý oddíl Docku: spuštěné nepřipnuté aplikace + nedávné (nejvýš 3), bez opakování
        var extra = Set<String>()
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if let id = app.bundleIdentifier, id != "com.apple.finder", !pinned.contains(id) { extra.insert(id) }
        }
        let showRecents = (dockPref("show-recents") as? Bool) ?? true
        if showRecents {
            for r in ((dockPref("recent-apps") as? [[String: Any]]) ?? []).prefix(3) {
                if let id = (r["tile-data"] as? [String: Any])?["bundle-identifier"] as? String, !pinned.contains(id) { extra.insert(id) }
            }
        }
        let recents = extra.count
        icons += others + recents
        let seps: CGFloat = (recents > 0 ? 1 : 0) + 1
        let pitch = tile + 5
        let width = CGFloat(icons) * pitch + spacers * pitch + seps * 12 + 16
        let half = min(width, f.width - 80) / 2
        dockL = mid - half + 10
        dockR = mid + half - 10
        dockExact = false
        if let b = bedSlot { bedXEstimate = mid - half + 8 + (b + 0.5) * pitch } else { bedXEstimate = nil }
    }
}
