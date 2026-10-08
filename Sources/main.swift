import Cocoa
import QuartzCore
import Carbon

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppController: NSObject, NSApplicationDelegate {
    var cfg = Config.load()
    let env = Env()
    var fx: Effects!
    var pet: Pet!
    var panel: PetPanel!
    var timer: Timer?
    let watch = Watch()
    var statusItem: NSStatusItem!
    var last = CACurrentMediaTime()
    var windowTick: CGFloat = 0

    // myš
    var wasDown = false
    var pressPending = false
    var pressPoint = CGPoint.zero
    var pressTime: CGFloat = 0
    var grabbing = false
    var hoverT: CGFloat = 0
    var sleeping = false
    var dockTick: CGFloat = 0
    var bedPress = false
    var bedDragging = false
    var bedGrab = CGPoint.zero
    var ballPress = false
    var ballHistory: [(CFTimeInterval, CGPoint)] = []
    var lastClaudeChanges = 0
    // úspora a schovávání
    var currentFPS: Double = 0
    var lastFastNeed = CACurrentMediaTime()
    var slowTick: CGFloat = 0
    var watchTick: CGFloat = 0
    var isHidden = false
    var mirrored = false
    var displayAsleep = false
    var locked = false
    var lastPose: DogPose?
    var lastFacing: CGFloat = 0
    var lastSide: CGFloat = 0
    var lastNotifyBark: CFTimeInterval = 0
    var claudeBusySince: CFTimeInterval = 0
    var claudeSentToBed = false
    var activeSeconds: CGFloat = 0
    var lastBellMinute = -1
    var lastFullscreen = false
    var lastMouse = CGPoint.zero
    var strokeSum: CGFloat = 0
    var strokeTurns = 0
    var lastStrokeDir: CGFloat = 1
    var px: CGFloat = 2
    var side: CGFloat = 230
    let debugLog = ProcessInfo.processInfo.environment["JULIE_DEBUG"] != nil
    var dbgT: CGFloat = 0

    func applicationDidFinishLaunching(_ n: Notification) {
        Texty.nastav(cfg.language)
        DogRenderer.load()
        env.refreshScreen()
        env.dockWidthOverride = CGFloat(cfg.dockWidth)
        env.refreshDock()
        env.refreshWindows(force: true)
        fx = Effects(scale: env.screen.backingScaleFactor)
        pet = Pet(cfg: cfg, env: env, fx: fx)
        buildPanel()
        buildMenu()
        applyLayout()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(spaceChanged),
                                                          name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(bedClicked(_:)),
                                                            name: NSNotification.Name("cz.karelhlas.julie.pelisek"), object: nil)
        registerTreatHotKey()
        applyAutostart()
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(displaySlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(displayWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(displaySlept), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        ws.addObserver(self, selector: #selector(displayWoke), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dn.addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        pet.startAir(v: .zero)
        setFPS(60)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.showWelcomeIfNeeded() }
    }

    // MARK: počet snímků za vteřinu (úspora baterie)

    /// Časovač se přestaví jen při změně; tolerance dovolí systému sdružovat probouzení.
    func setFPS(_ f: Double) {
        if f == currentFPS { return }
        currentFPS = f
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / f, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.2 / f
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Kolik snímků teď Julie potřebuje: hod a pád 60, chůze 30, klid 10, spánek 6.
    func desiredFPS(_ mouse: CGPoint) -> Double {
        let now = CACurrentMediaTime()
        if grabbing || pressPending || bedPress || ballPress || pet.needsFastFrames || fx.isBusy {
            lastFastNeed = now
            return 60
        }
        let near = hypot(mouse.x - pet.pos.x, mouse.y - pet.pos.y) < 260
        var want: Double = 15
        if pet.speedNow > 1 || near || fx.hasHeldTreat { want = 30 }
        else if pet.isResting { want = [.sleep, .inBed, .lie].contains(pet.act) ? 6 : 10 }
        // dolů až po vteřině klidu (ať neposkakuje mezi rychlostmi)
        if want < currentFPS && now - lastFastNeed < 1 { return currentFPS }
        if want >= currentFPS { lastFastNeed = now }
        return want
    }

    // MARK: schovávání (celá obrazovka, zrcadlení, spánek displeje, zámek, uspání z menu)

    @objc func displaySlept() { displayAsleep = true }
    @objc func displayWoke() { displayAsleep = false; last = CACurrentMediaTime() }
    @objc func screenLocked() { locked = true }
    @objc func screenUnlocked() { locked = false; last = CACurrentMediaTime() }

    var pausedUntil: Date? {
        if cfg.pausedForever { return Date.distantFuture }
        guard let t = cfg.pausedUntil, t > Date().timeIntervalSince1970 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    var shouldHide: Bool {
        if displayAsleep || locked || pausedUntil != nil || mirrored { return true }
        if env.fullscreen { return !cfg.showInFullscreen }
        return !env.dockAvailable
    }

    /// Schovat = okno pryč, zrušit rozdělaná tažení, simulace stojí; ukázat = vrátit a navázat bez skoku v čase.
    func setHidden(_ h: Bool) {
        isHidden = h
        if h {
            if grabbing { grabbing = false; pet.resetForScreenChange() }
            pressPending = false; bedPress = false; bedDragging = false; ballPress = false
            if fx.hasHeldTreat { fx.dropHeld() }
            panel.orderOut(nil)
        } else {
            env.refreshScreen(); env.refreshDock(); env.refreshWindows(force: true)
            panel.orderFrontRegardless()
            last = CACurrentMediaTime()
        }
        zapis("Julie \(h ? "schovaná" : "zpět") (celá obrazovka \(env.fullscreen), zrcadlení \(mirrored), Dock \(env.dockAvailable ? "ok" : "nedostupný"), spánek \(displayAsleep), zámek \(locked), uspaná \(pausedUntil != nil))")
        rebuildMenu()
    }

    /// Přepnutí plochy (i na aplikaci na celé obrazovce): okno s Julií znovu dopředu.
    @objc func spaceChanged() {
        env.refreshWindows(force: true)
        panel.orderFrontRegardless()
    }

    @objc func screenChanged() {
        env.refreshScreen()
        env.refreshDock()
        env.refreshWindows(force: true)
        panel.setFrame(env.screen.frame, display: true)
        fx.root.frame = CGRect(origin: .zero, size: env.screen.frame.size)
        fx.setScale(env.screen.backingScaleFactor)
        if grabbing { grabbing = false }
        pressPending = false; bedPress = false; bedDragging = false; ballPress = false
        pet.resetForScreenChange()
        lastPose = nil
        last = CACurrentMediaTime()
        zapis("změna monitorů: obrazovka \(Int(env.screen.frame.width))×\(Int(env.screen.frame.height))")
    }

    func buildPanel() {
        let f = env.screen.frame
        panel = PetPanel(contentRect: f, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // na všech plochách včetně aplikací na celé obrazovce
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        let v = NSView(frame: CGRect(origin: .zero, size: f.size))
        fx.root.frame = v.bounds
        v.layer = fx.root
        v.wantsLayer = true
        panel.contentView = v
        panel.orderFrontRegardless()
    }

    func applyLayout() {
        pet.cfg = cfg
        px = max(2, (CGFloat(cfg.size) / 38).rounded())
        side = (CGFloat(cfg.size) * 3.0 / px).rounded() * px
        pet.pixel = px
        fx.px = px
        fx.dogLayer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
    }

    // MARK: smyčka

    func tick() {
        let now = CACurrentMediaTime()
        let rawDt = CGFloat(max(0, now - last))
        last = now
        let dt = min(rawDt, 0.1)        // pro myš a tažení
        env.followFullscreen = cfg.showInFullscreen
        // stav obrazovky dvakrát za vteřinu (celá obrazovka, zrcadlení), Dock jednou za 3 s
        slowTick += rawDt
        if slowTick > 0.5 {
            slowTick = 0
            env.refreshFullscreen()
            mirrored = Env.mainDisplayMirrored() || (cfg.hideOnExternalMain && Env.mainIsExternalWhileBuiltinOn())
            minuteChecks(rawDt: 0.5)
        }
        dockTick += rawDt
        if dockTick > 3 {
            dockTick = 0
            env.dockWidthOverride = CGFloat(cfg.dockWidth)
            env.refreshScreen()
            env.refreshDock()
        }
        let hide = shouldHide
        if hide != isHidden { setHidden(hide) }
        if hide { setFPS(2); return }
        if pet.needsWindows { env.refreshWindows() }
        if cfg.claudeWatch {
            watchTick += rawDt
            if watchTick > 0.25 { watchTick = 0; watch.poll() }
        }
        fx.treatRange = (env.dockL + 20)...max(env.dockL + 21, env.dockR - 20)

        pet.bedSpot = bedSpot()
        let mouse = NSEvent.mouseLocation
        if fx.hasHeldTreat {
            let p = CGPoint(x: mouse.x + Effects.heldOffset.x, y: mouse.y + Effects.heldOffset.y)
            fx.moveHeld(to: p)
            pet.heldTreatPos = p
        } else {
            pet.heldTreatPos = nil
        }
        let down = NSEvent.pressedMouseButtons & 1 != 0
        let typing = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown) < 0.35

        // Claude Code: při každé nové zprávě od háčku krátká reakce
        pet.watchAct = nil
        pet.watchText = nil
        if watch.active == nil || watch.active == "done" || watch.active == "notify" { claudeBusySince = 0; claudeSentToBed = false }
        if watch.changes != lastClaudeChanges {
            lastClaudeChanges = watch.changes
            if cfg.claudeWatch, let tok = watch.active { pet.reactToClaude(tok); lastNotifyBark = now }
        } else if cfg.claudeWatch, let tok = watch.active, ["think", "bash", "read", "edit", "web", "task"].contains(tok) {
            // Claude pracuje dlouho (přes 2 minuty bez zastavení): Julie si jde lehnout do pelíšku
            if claudeBusySince == 0 { claudeBusySince = now }
            if now - claudeBusySince > 120 && !claudeSentToBed && pet.mode == .ground
                && [.walk, .sit, .look, .sniff, .lie, .scrabble].contains(pet.act) {
                claudeSentToBed = true
                pet.goToBed(untilClick: false)
            }
        } else if cfg.claudeWatch, watch.active == "notify", now - lastNotifyBark > 4 {
            lastNotifyBark = now
            pet.reactToClaude("notify")         // Claude pořád čeká na tebe: Julie občas štěkne
        }

        // myš a Julie
        let over = pet.hitRect.contains(mouse)
        let overBed = fx.bedRect.contains(mouse)
        let overBall = fx.ballRect.contains(mouse)
        // míček: chytit myší a hodit
        if down && !wasDown && overBall && !over {
            ballPress = true
            ballHistory = []
        }
        if ballPress {
            if down {
                pet.holdBall(at: mouse)
                ballHistory.append((CACurrentMediaTime(), mouse))
                if ballHistory.count > 10 { ballHistory.removeFirst() }
            } else {
                ballPress = false
                var v = CGPoint.zero
                let now = CACurrentMediaTime()
                let recent = ballHistory.filter { now - $0.0 < 0.1 }
                if let a = recent.first, let b = recent.last, b.0 - a.0 > 0.01 {
                    v = CGPoint(x: (b.1.x - a.1.x) / CGFloat(b.0 - a.0), y: (b.1.y - a.1.y) / CGFloat(b.0 - a.0))
                }
                let m = hypot(v.x, v.y), maxV: CGFloat = 2200
                if m > maxV { v = CGPoint(x: v.x / m * maxV, y: v.y / m * maxV) }
                pet.throwBall(from: mouse, vel: v)
            }
        }
        // pelíšek: kliknutí = spát / vstávat, tažení = přesunout (místo se uloží)
        if down && !wasDown && overBed && !over && !ballPress, let spot = pet.bedSpot {
            bedPress = true
            pressPoint = mouse
            bedGrab = CGPoint(x: mouse.x - spot.x, y: mouse.y - spot.y)
        }
        if bedPress && down && hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) >= 6 { bedDragging = true }
        if bedDragging && down {
            let f = env.screen.frame
            cfg.bedDX = Double(mouse.x - bedGrab.x - (env.dockR + 10))
            cfg.bedDY = Double(mouse.y - bedGrab.y - f.minY)
            pet.cfg.bedDX = cfg.bedDX
            pet.cfg.bedDY = cfg.bedDY
        }
        if bedPress && !down {
            if bedDragging { cfg.save(); rebuildMenu() } else { pet.bedToggle() }
            bedPress = false
            bedDragging = false
        }
        handleMouse(over: over && !ballPress && !bedPress, down: down, mouse: mouse, dt: dt)
        if env.fullscreen != lastFullscreen {
            lastFullscreen = env.fullscreen
            zapis("celá obrazovka: \(env.fullscreen ? "ano" : "ne")")
        }
        let hidden = env.fullscreen && !cfg.showInFullscreen
        panel.alphaValue = hidden ? 0 : 1
        panel.ignoresMouseEvents = hidden || !(over || overBed || overBall || grabbing || pressPending || bedPress || ballPress)

        pet.hover = over && !down ? pet.hover + dt : 0
        // hlazení = přejíždění kurzorem sem a tam po Julii
        strokeSum *= exp(-dt * 1.2)
        if over && !down && !grabbing {
            let dx = mouse.x - lastMouse.x
            if dx != 0 && (dx > 0) != (lastStrokeDir > 0) { strokeTurns += 1 }
            if abs(dx) > 0.5 { lastStrokeDir = dx }
            strokeSum += abs(dx)
            if strokeSum > 160 && strokeTurns >= 2 {
                pet.petted()
                strokeSum = 60
            }
        } else {
            strokeTurns = 0
        }
        lastMouse = mouse

        if grabbing { pet.dragTo(mouse, dt) }
        // simulace po krocích nejvýš 1/30 s: při nižším počtu snímků se nic nezpomalí
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        Pet.step(pet, fx, rawDt, Input(mouse: mouse, typing: typing), floorY: env.floorY)
        CATransaction.commit()
        render()
        setFPS(desiredFPS(mouse))
        if debugLog {
            dbgT += dt
            if dbgT > 1 {
                dbgT = 0
                let line = String(format: "mode=%@ act=%@ pos=(%.0f,%.0f) floor=%.0f surf=%d wins=%d speed=%.0f dock=%.0f-%.0f bed=%.0f\n", "\(pet.mode)", "\(pet.act)", pet.pos.x, pet.pos.y, env.floorY, pet.surfaceId, env.windows.count, pet.speedNow, env.dockL, env.dockR, pet.bedX ?? -1)
                if let h = FileHandle(forWritingAtPath: "/tmp/julie.log") { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!) }
                else { try? line.write(toFile: "/tmp/julie.log", atomically: true, encoding: .utf8) }
            }
        }
    }

    func handleMouse(over: Bool, down: Bool, mouse: CGPoint, dt: CGFloat) {
        if down && !wasDown && over && !grabbing {
            pressPending = true
            pressPoint = mouse
            pressTime = 0
        }
        if pressPending && down {
            pressTime += dt
            if hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) > 5 || pressTime > 0.22 {
                pressPending = false
                grabbing = true
                pet.beginGrab(mouse)
            }
        }
        if !down && wasDown {
            if grabbing {
                grabbing = false
                pet.release()
            } else if pressPending {
                pressPending = false
                if pet.act == .inBed { pet.bedToggle() } else { pet.poke() }
            }
        }
        if !down { pressPending = false }
        wasDown = down
    }

    func render() {
        let p = pet.buildPose().quantized()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // obrázek kreslit znovu jen při změně (jinak se jen posouvá vrstva)
        if p != lastPose || pet.facing != lastFacing || side != lastSide {
            fx.dogLayer.contents = DogRenderer.sprite(pose: p, scale: pet.s, facing: pet.facing, side: side, px: px)
            lastPose = p; lastFacing = pet.facing; lastSide = side
        }
        let cx = pet.pos.x, cy = pet.pos.y + pet.yOff
        fx.dogLayer.position = CGPoint(x: ((cx - side / 2) / px).rounded() * px + side / 2,
                                       y: ((cy - side / 2) / px).rounded() * px + side / 2)
        fx.setBed(bottom: pet.bedSpot, inside: pet.act == .inBed && pet.mode == .ground)
        // míček v tlamě je nakreslený přímo ve snímku Julie (pokud snímky s míčkem máme)
        let carriedInFrame = pet.ball?.carried == true && p.frame.hasPrefix("mic_")
        fx.setBall(carriedInFrame ? nil : pet.ball?.pos)
        // bublina nad hlavou
        let text = pet.bubbleText
        fx.bubble.set(text, scale: env.screen.backingScaleFactor)
        if text != nil {
            let s = pet.s
            var bx = pet.pos.x + 12 * s * pet.facing
            var by = pet.pos.y + 62 * s + pet.yOff
            if pet.mode == .climb || pet.mode == .mantle || pet.mode == .grab { by = pet.pos.y + 74 * s; bx = pet.pos.x }
            if pet.mode == .balloon { by = pet.pos.y + 125 * s }
            let half = fx.bubble.bounds.width / 2
            bx = min(env.right - half - 4, max(env.left + half + 4, bx))
            by = min(env.screen.frame.maxY - 40, by)
            fx.bubble.position = CGPoint(x: bx, y: by)
        }
        CATransaction.commit()
    }

    // MARK: přestávka (volitelně) a zvonění

    /// Volá se dvakrát za vteřinu.
    func minuteChecks(rawDt: CGFloat) {
        // přestávka: po 50 minutách práce v kuse (bez 5min pauzy) Julie přiběhne pod kurzor a štěkne
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        if idle > 300 { activeSeconds = 0 } else { activeSeconds += rawDt }
        if cfg.breakReminder && activeSeconds > 50 * 60 {
            activeSeconds = 40 * 60          // když pokračuješ, připomene se znovu za 10 minut
            pet.call(to: NSEvent.mouseLocation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                if let p = self?.pet, p.mode == .ground, [.follow, .happy, .sit].contains(p.act) { p.setAct(.bark, 2) }
            }
            zapis("přestávka: Julie připomněla")
        }
        // zvonění: 2 minuty před zvoněním se protáhne (časy v nastavení „zvoneni“)
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        if m != lastBellMinute {
            lastBellMinute = m
            for t in cfg.zvoneni {
                let parts = t.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2, parts[0] * 60 + parts[1] - 2 == m, pet.mode == .ground,
                   [.walk, .sit, .look, .sniff, .lie].contains(pet.act) {
                    pet.setAct(.stretch, 1.8)
                }
            }
        }
    }

    // MARK: menu

    func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let ikona = ikonaKosti() {
            statusItem.button?.image = ikona
            statusItem.button?.imagePosition = .imageOnly
        } else {
            statusItem.button?.title = "🦴"
        }
        statusItem.button?.toolTip = "Julie"
        statusItem.button?.setAccessibilityLabel("Julie")
        rebuildMenu()
    }

    /// Ikona v horní liště: pixelová kost (kost.png) jako šablona. macOS ji sám obarví a ztlumí
    /// stejně jako ostatní ikony (emoji 🦴 zůstávalo vždy jasné). Malinká: 1 bod na pixel (13 × 9 bodů).
    func ikonaKosti() -> NSImage? {
        guard let src = DogRenderer.frames["kost"] else { return nil }
        let w = src.width, h = src.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let img = NSImage(size: NSSize(width: w, height: h))
        for k in [1, 2] {                                   // @1x a @2x
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w * k, pixelsHigh: h * k, bitsPerSample: 8,
                                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            rep.size = NSSize(width: w, height: h)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.black.setFill()
            for y in 0..<h {
                for x in 0..<w where data[(y * w + x) * 4 + 3] > 128 {
                    // první řádek dat je horní okraj obrázku, AppKit kreslí odspodu
                    NSRect(x: CGFloat(x * k), y: CGFloat((h - 1 - y) * k), width: CGFloat(k), height: CGFloat(k)).fill()
                }
            }
            NSGraphicsContext.restoreGraphicsState()
            img.addRepresentation(rep)
        }
        img.isTemplate = true
        return img
    }

    func item(_ title: String, _ sel: Selector, checked: Bool? = nil, tag: Int = 0) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        it.target = self
        it.tag = tag
        if let c = checked { it.state = c ? .on : .off }
        return it
    }

    func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let m = NSMenu()
        items.forEach { m.addItem($0) }
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.submenu = m
        return it
    }

    func info(_ text: String) -> NSMenuItem {
        let it = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    func rebuildMenu() {
        let t = Texty.t
        let m = NSMenu()
        m.addItem(item(t("treat", ""), #selector(giveTreat)))
        m.addItem(item(t("ball", ""), #selector(ballHotKey)))
        m.addItem(item(t("bed", ""), #selector(bedMenu)))
        m.addItem(item(t("call", ""), #selector(callJulie)))
        m.addItem(.separator())
        if cfg.pausedForever {
            m.addItem(item(t("wakeForever", ""), #selector(unpause)))
        } else if let until = pausedUntil {
            let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short
            m.addItem(item(t("wakeUntil", f.string(from: until)), #selector(unpause)))
        } else {
            m.addItem(submenu(t("sleep", ""), [
                item(t("sleepHour", ""), #selector(pauseHour)),
                item(t("sleepTomorrow", ""), #selector(pauseTomorrow)),
                item(t("sleepForever", ""), #selector(pauseForever))]))
        }
        m.addItem(submenu(t("surprise", ""), ["balloons", "squirrel", "treatRain", "burrow"].enumerated().map { item(t($1, ""), #selector(runEgg(_:)), tag: $0) }))
        let sizes = [("small", 56), ("medium", 80), ("large", 110), ("huge", 150)].enumerated().map { i, v in
            item(t(v.0, ""), #selector(setSize(_:)), checked: Int(cfg.size) == v.1, tag: i) }
        let speeds = ["slow", "normal", "fast"].enumerated().map { i, n in
            item(t(n, ""), #selector(setSpeed(_:)), checked: abs(cfg.walkSpeed - [0.6, 1.0, 1.6][i]) < 0.01, tag: i) }
        var langs = [item(t("auto", ""), #selector(setLanguage(_:)), checked: cfg.language == "auto", tag: 0)]
        for (i, l) in Texty.jazyky.enumerated() {
            langs.append(item(l.nazev, #selector(setLanguage(_:)), checked: cfg.language == l.kod, tag: i + 1))
        }
        var settings: [NSMenuItem] = [
            submenu(t("size", ""), sizes),
            submenu(t("speed", ""), speeds),
            submenu(t("language", ""), langs),
            .separator(),
            item(t("autostart", ""), #selector(toggleAutostart), checked: cfg.autostart),
            item(t("claude", ""), #selector(toggleWatch), checked: cfg.claudeWatch),
            item(t("turn", ""), #selector(toggleEyes), checked: cfg.eyeTracking),
            item(t("climb", ""), #selector(togglePlatforms), checked: cfg.windowPlatforms),
            item(t("mischief", ""), #selector(toggleMischief), checked: cfg.mischief),
            item(t("fullscreen", ""), #selector(toggleFullscreen), checked: cfg.showInFullscreen),
            item(t("projector", ""), #selector(toggleExternalMain), checked: cfg.hideOnExternalMain),
            item(t("break", ""), #selector(toggleBreak), checked: cfg.breakReminder),
            .separator()]
        settings.append(ClaudeHooks.installed ? item(t("claudeDisconnect", ""), #selector(claudeDisconnect))
                                              : item(t("claudeConnect", ""), #selector(claudeConnect)))
        if cfg.bedDX != nil { settings.append(item(t("bedReset", ""), #selector(resetBed))) }
        settings.append(item(env.dockExact ? t("dockExact", "") : t("dockMeasure", ""), #selector(askAX)))
        m.addItem(submenu(t("settings", ""), settings))
        m.addItem(submenu(t("help", ""), ["h1", "h2", "h3", "h4", "h5", "h6"].map { info(t($0, "")) }))
        m.addItem(.separator())
        m.addItem(item(t("quit", ""), #selector(quit)))
        statusItem.menu = m
    }

    @objc func setLanguage(_ s: NSMenuItem) {
        cfg.language = s.tag == 0 ? "auto" : Texty.jazyky[s.tag - 1].kod
        Texty.nastav(cfg.language)
        persist()
    }

    // MARK: úvodní okno (první spuštění)

    func showWelcomeIfNeeded() {
        guard !cfg.welcomed else { return }
        cfg.welcomed = true
        cfg.save()
        let a = NSAlert()
        a.messageText = Texty.t("welcomeTitle")
        a.informativeText = Texty.t("welcomeText")
        if let img = DogRenderer.frames["stoji"] {
            let big = NSImage(cgImage: img, size: NSSize(width: CGFloat(img.width) * 3, height: CGFloat(img.height) * 3))
            a.icon = big
        }
        let check = NSButton(checkboxWithTitle: Texty.t("welcomeAutostart"), target: nil, action: nil)
        check.state = cfg.autostart ? .on : .off
        a.accessoryView = check
        a.addButton(withTitle: Texty.t("ok"))
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
        cfg.autostart = check.state == .on
        cfg.save()
        applyAutostart()
        rebuildMenu()
    }

    // MARK: Claude Code (propojení přímo z aplikace)

    @objc func claudeConnect() {
        guard ClaudeHooks.claudeExists else { simpleAlert(Texty.t("claudeMissing")); return }
        let a = NSAlert()
        a.messageText = Texty.t("claudeTitle")
        a.informativeText = Texty.t("claudeText")
        a.addButton(withTitle: Texty.t("claudeYes"))
        a.addButton(withTitle: Texty.t("cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        if ClaudeHooks.install() {
            cfg.claudeWatch = true
            persist()
            simpleAlert(Texty.t("claudeDone"))
        }
    }

    @objc func claudeDisconnect() {
        if ClaudeHooks.uninstall() { rebuildMenu(); simpleAlert(Texty.t("claudeRemoved")) }
    }

    func simpleAlert(_ text: String) {
        let a = NSAlert()
        a.messageText = text
        NSApp.activate(ignoringOtherApps: true)
        a.runModal()
    }

    func persist() { cfg.save(); applyLayout(); rebuildMenu() }

    @objc func toggleWatch() { cfg.claudeWatch.toggle(); persist() }
    @objc func pauseHour() { cfg.pausedUntil = Date().addingTimeInterval(3600).timeIntervalSince1970; cfg.save(); rebuildMenu() }
    @objc func pauseTomorrow() {
        var d = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        d = d.addingTimeInterval(6 * 3600)          // zítra v 6:00
        cfg.pausedUntil = d.timeIntervalSince1970; cfg.save(); rebuildMenu()
    }
    @objc func pauseForever() { cfg.pausedForever = true; cfg.save(); rebuildMenu() }
    @objc func unpause() { cfg.pausedUntil = nil; cfg.pausedForever = false; cfg.save(); rebuildMenu() }
    @objc func toggleExternalMain() { cfg.hideOnExternalMain.toggle(); persist() }
    @objc func toggleBreak() { cfg.breakReminder.toggle(); persist() }
    @objc func toggleAutostart() { cfg.autostart.toggle(); persist(); applyAutostart() }
    @objc func resetBed() { cfg.bedDX = nil; cfg.bedDY = nil; pet.cfg.bedDX = nil; pet.cfg.bedDY = nil; persist() }
    @objc func toggleEyes() { cfg.eyeTracking.toggle(); persist() }
    @objc func togglePlatforms() { cfg.windowPlatforms.toggle(); persist() }
    @objc func toggleFullscreen() { cfg.showInFullscreen.toggle(); env.followFullscreen = cfg.showInFullscreen; env.applyFloor(); persist() }
    @objc func toggleMischief() { cfg.mischief.toggle(); persist() }
    @objc func setSize(_ s: NSMenuItem) { cfg.size = Double([56, 80, 110, 150][s.tag]); persist() }
    @objc func setSpeed(_ s: NSMenuItem) { cfg.walkSpeed = [0.6, 1.0, 1.6][s.tag]; persist() }
    /// Pelíšek stojí vpravo vedle Docku (když není místo, tak vlevo), svisle uprostřed pruhu Docku.
    func bedSpot() -> CGPoint? {
        let size = fx.bedSize
        guard size.width > 0 else { return nil }
        let f = env.screen.frame
        let band = env.floorY - f.minY
        let gap: CGFloat = 14
        let pillR = env.dockR + 10, pillL = env.dockL - 10
        if let dx = cfg.bedDX, let dy = cfg.bedDY {
            // přetažený myší: drží se vůči pravému konci Docku
            let x = min(f.maxX - size.width / 2, max(f.minX + size.width / 2, pillR + CGFloat(dx)))
            let y = min(f.maxY - size.height - 30, max(f.minY, f.minY + CGFloat(dy)))
            // stojí v pruhu Docku, ale je na něj moc vysoký: nezobrazovat
            if y < env.floorY - 1 && y + size.height > env.floorY + 1 { return nil }
            return CGPoint(x: x, y: y)
        }
        // pelíšek se musí vejít do pruhu vedle Docku; když se nevejde (velká Julie, schovaný Dock), není
        if band < size.height { return nil }
        var x = pillR + gap + size.width / 2
        if x + size.width / 2 > f.maxX - 4 { x = pillL - gap - size.width / 2 }
        if x - size.width / 2 < f.minX + 4 { return nil }
        return CGPoint(x: x, y: f.minY + (band - size.height) / 2)
    }

    // MARK: klávesová zkratka ⌃⌥P = pamlsek

    var hotKeyRef: EventHotKeyRef?
    var ballKeyRef: EventHotKeyRef?

    /// Globální zkratka přes Carbon: funguje v každé aplikaci a nepotřebuje oprávnění Zpřístupnění.
    func registerTreatHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, ev, ud in
            guard let ud = ud else { return noErr }
            var hk = EventHotKeyID()
            GetEventParameter(ev, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let me = Unmanaged<AppController>.fromOpaque(ud).takeUnretainedValue()
            DispatchQueue.main.async { if hk.id == 2 { me.ballHotKey() } else { me.treatHotKey() } }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
        let st = RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey),
                                     EventHotKeyID(signature: OSType(0x4A554C49), id: 1), GetApplicationEventTarget(), 0, &hotKeyRef)
        let st2 = RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(controlKey | optionKey),
                                      EventHotKeyID(signature: OSType(0x4A554C49), id: 2), GetApplicationEventTarget(), 0, &ballKeyRef)
        zapis("zkratky ⌃⌥P / ⌃⌥M zaregistrovány: \(st == noErr ? "ano" : "ne (\(st))") / \(st2 == noErr ? "ano" : "ne (\(st2))")")
    }

    /// Krátký deník událostí v ~/.jezevcik/udalosti.log (posledních ~200 řádků) kvůli hledání chyb.
    func zapis(_ text: String) {
        let path = Config.dir + "/udalosti.log"
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        let line = "\(f.string(from: Date())) \(text)\n"
        var old = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let lines = old.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > 200 { old = lines.suffix(150).joined(separator: "\n") }
        try? FileManager.default.createDirectory(atPath: Config.dir, withIntermediateDirectories: true)
        try? (old + line).write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// ⌃⌥P: pamlsek se objeví u kurzoru a Julie si pro něj přijde; další ⌃⌥P ho pustí na zem.
    @objc func treatHotKey() {
        let m = NSEvent.mouseLocation
        zapis("⌃⌥P: pamlsek \(fx.hasHeldTreat ? "puštěn" : "u kurzoru") (x \(Int(m.x)), y \(Int(m.y))), Julie: \(pet.mode) \(pet.act)")
        if !env.screen.frame.contains(m) {
            // kurzor je na druhém monitoru: pamlsek spadne na Dock kousek od Julie
            pet.giveTreat(CGPoint(x: pet.pos.x + CGFloat.random(in: -200...200), y: env.ceilY))
            return
        }
        if fx.hasHeldTreat {
            fx.dropHeld()
            if pet.act == .fetch { pet.setAct(.sausage, 999) }
        } else {
            fx.holdTreat(at: CGPoint(x: m.x + Effects.heldOffset.x, y: m.y + Effects.heldOffset.y))
            pet.heldTreatPos = CGPoint(x: m.x + Effects.heldOffset.x, y: m.y + Effects.heldOffset.y)
            pet.fetchTreat()
        }
    }

    /// ⌃⌥M: hodí míček od kurzoru směrem k Docku.
    @objc func ballHotKey() {
        var m = NSEvent.mouseLocation
        if !env.screen.frame.contains(m) {
            // kurzor je na druhém monitoru: míček přiletí shora nad Julií
            m = CGPoint(x: pet.pos.x + CGFloat.random(in: -250...250), y: env.ceilY - 20)
        }
        let mid = (env.dockL + env.dockR) / 2
        let vx = max(-520, min(520, (mid - m.x) * 0.6)) + CGFloat.random(in: -140...140)
        pet.throwBall(from: m, vel: CGPoint(x: vx, y: 220))
        zapis("⌃⌥M: míček (x \(Int(m.x)), y \(Int(m.y))), Julie: \(pet.mode) \(pet.act)")
    }

    // MARK: spouštění po přihlášení

    var launchAgentPath: String { NSHomeDirectory() + "/Library/LaunchAgents/cz.karelhlas.julie.plist" }

    func applyAutostart() {
        let fm = FileManager.default
        if cfg.autostart {
            let plist: [String: Any] = ["Label": "cz.karelhlas.julie",
                                        "ProgramArguments": ["/usr/bin/open", "-g", Bundle.main.bundlePath],
                                        "RunAtLoad": true]
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
               fm.contents(atPath: launchAgentPath) != data {
                try? fm.createDirectory(atPath: (launchAgentPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                try? data.write(to: URL(fileURLWithPath: launchAgentPath))
                zapis("spouštění po přihlášení: zapnuto")
            }
        } else if fm.fileExists(atPath: launchAgentPath) {
            try? fm.removeItem(atPath: launchAgentPath)
            zapis("spouštění po přihlášení: vypnuto")
        }
    }

    /// Kliknutí na ikonu Pelíšek v Docku.
    @objc func bedClicked(_ n: Notification) { pet.bedToggle() }
    @objc func bedMenu() { pet.bedToggle() }
    @objc func giveTreat() { pet.giveTreat(NSEvent.mouseLocation) }
    @objc func callJulie() { pet.call(to: NSEvent.mouseLocation) }
    @objc func toggleSleep() {
        guard pet.mode == .ground else { return }
        if pet.act == .sleep || pet.act == .lie { pet.setAct(.stretch, 1.6) } else { pet.setAct(.lie, 2) }
    }
    @objc func runEgg(_ s: NSMenuItem) {
        guard pet.mode == .ground else { return }
        if pet.surfaceId != 0 { pet.startAir(v: .zero); return }
        switch s.tag {
        case 0, 1, 2: pet.startEgg(s.tag)
        default: pet.setAct(.dig, 4.6)       // Nora
        }
    }
    @objc func askAX() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        env.refreshDock()
        rebuildMenu()
    }
    @objc func quit() { NSApp.terminate(nil) }
}

// MARK: náhled póz (jezevcik --sheet cesta.png)

func renderSheet(to path: String) {
    _ = NSApplication.shared
    DogRenderer.load()
    let env = Env()
    let fx = Effects(scale: 2)
    var cfg = Config()
    cfg.size = 80
    let pet = Pet(cfg: cfg, env: env, fx: fx)
    struct Cell { var name: String; var setup: (Pet) -> Void }
    let cells: [Cell] = [
        Cell(name: "stoji") { p in p.setAct(.sit, 1); p.mode = .ground; p.act = .look; p.actT = 0.4 },
        Cell(name: "chuze1") { p in p.act = .walk; p.speedNow = 55; p.phase = 0.3 },
        Cell(name: "chuze2") { p in p.act = .walk; p.speedNow = 55; p.phase = 2.0 },
        Cell(name: "beh") { p in p.act = .follow; p.speedNow = 110; p.phase = 1.0 },
        Cell(name: "sed") { p in p.act = .sit },
        Cell(name: "lezi") { p in p.act = .lie },
        Cell(name: "spi") { p in p.act = .sleep },
        Cell(name: "cuch") { p in p.act = .sniff },
        Cell(name: "drbe") { p in p.act = .scratch },
        Cell(name: "protaha") { p in p.act = .stretch; p.actT = 1 },
        Cell(name: "stekot") { p in p.act = .bark; p.actT = 0.15 },
        Cell(name: "radost") { p in p.act = .happy; p.actT = 0.2 },
        Cell(name: "hrabe") { p in p.act = .dig; p.actT = 1.0; p.sinkAmt = 0 },
        Cell(name: "zapada") { p in p.act = .dig; p.actT = 2.0; p.sinkAmt = 0.55 },
        Cell(name: "lezeni") { p in p.mode = .climb; p.rot = .pi / 2; p.phase = 1 },
        Cell(name: "drzena") { p in p.mode = .grab; p.rot = .pi / 2 + 0.3; p.phi = 0.3 },
        Cell(name: "vzduch") { p in p.mode = .air; p.vel = CGPoint(x: 500, y: -300); p.stretchExtra = 0.2 },
        Cell(name: "balonky") { p in p.mode = .balloon; p.balloons = 3 },
        Cell(name: "dopad") { p in p.act = .sit; p.q = 0.45 },
        Cell(name: "ocas") { p in p.act = .dizzy },
    ]
    let cols = 5
    let cw = 240, ch = 240
    let rows = (cells.count + cols - 1) / cols
    let W = cols * cw, H = rows * ch
    guard let ctx = CGContext(data: nil, width: W * 2, height: H * 2, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    ctx.scaleBy(x: 2, y: 2)
    ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.95, blue: 0.97, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (i, cell) in cells.enumerated() {
        let cx = (i % cols) * cw, cy = H - (i / cols + 1) * ch
        pet.mode = .ground; pet.rot = 0; pet.q = 0; pet.phi = 0; pet.facing = 1
        pet.speedNow = 0; pet.stretchExtra = 0; pet.balloons = 0; pet.sinkAmt = 0; pet.vel = .zero
        pet.act = .sit; pet.actT = 0.5; pet.phase = 0
        cell.setup(pet)
        let pose = pet.buildPose()
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(cx), y: CGFloat(cy))
        ctx.setStrokeColor(CGColor(srgbRed: 0.8, green: 0.82, blue: 0.85, alpha: 1))
        ctx.stroke(CGRect(x: 0, y: 0, width: cw, height: ch))
        // zem
        ctx.setStrokeColor(CGColor(srgbRed: 0.4, green: 0.4, blue: 0.4, alpha: 1))
        ctx.move(to: CGPoint(x: 10, y: 60)); ctx.addLine(to: CGPoint(x: 230, y: 60)); ctx.strokePath()
        ctx.translateBy(x: 0, y: 60 - 24 - 56 + 56 + 0)
        ctx.translateBy(x: 0, y: 0)
        // střed těla je 24 nad zemí => posun
        ctx.translateBy(x: 0, y: 0)
        let size = CGSize(width: 240, height: 240)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: -(120 - 24))
        if let img = DogRenderer.sprite(pose: pose, scale: 0.8, facing: 1, side: 240, px: 2) {
            ctx.interpolationQuality = .none
            ctx.draw(img, in: CGRect(origin: .zero, size: size))
        }
        ctx.restoreGState()
        ctx.restoreGState()
        let label = NSAttributedString(string: cell.name, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray])
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        label.draw(at: CGPoint(x: CGFloat(cx) + 6, y: CGFloat(cy) + CGFloat(ch) - 18))
        NSGraphicsContext.restoreGraphicsState()
    }
    if let img = ctx.makeImage() {
        let rep = NSBitmapImageRep(cgImage: img)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Filmový pás nory: jezevcik --nora cesta.png
func renderBurrow(to path: String) {
    _ = NSApplication.shared
    DogRenderer.load()
    let env = Env()
    let fx = Effects(scale: 2)
    var cfg = Config()
    cfg.size = 80
    cfg.mischief = false
    let pet = Pet(cfg: cfg, env: env, fx: fx)
    pet.pixel = 2
    pet.mode = .ground
    pet.surfaceId = 0
    pet.pos = CGPoint(x: (env.dockL + env.dockR) / 2, y: env.floorY + DogRenderer.ground * pet.s)
    pet.facing = 1
    pet.forceFacing = -1          // vynutit otočení po vynoření
    pet.setAct(.dig, 1)
    let inp = Input(mouse: CGPoint(x: -9999, y: -9999), typing: false)
    var shots: [(String, CGImage?, CGFloat?)] = []
    var t: CGFloat = 0, next: CGFloat = 0
    let dt: CGFloat = 1.0 / 60
    while t < 12 && pet.act == .dig {
        pet.update(dt, inp)
        t += dt
        if t >= next {
            next += 0.18
            let pose = pet.buildPose()
            // díra tam, kam ji opravdu položila aplikace (v pixelech obrázku vůči Julii)
            let hx: CGFloat? = (pet.burrowPhase <= 2 || (pet.burrowPhase >= 4 && pet.burrowPhase <= 6)) ? (pet.lastHoleX - pet.pos.x) / pet.pixel : nil
            shots.append(("\(pet.burrowPhase) f\(Int(pet.facing))", DogRenderer.sprite(pose: pose, scale: pet.s, facing: pet.facing, side: 240, px: 2), hx))
        }
    }
    let cols = 8, cw = 120, ch = 120
    let rows = (shots.count + cols - 1) / cols
    guard let ctx = CGContext(data: nil, width: cols * cw, height: rows * ch, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.95, blue: 0.97, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: cols * cw, height: rows * ch))
    ctx.interpolationQuality = .none
    for (i, (label, img, hx)) in shots.enumerated() {
        let x = (i % cols) * cw, y = (rows - 1 - i / cols) * ch
        let groundY = CGFloat(y) + 60 - (DogRenderer.ground * pet.s / 2).rounded()
        if let hx = hx {
            ctx.setFillColor(CGColor(srgbRed: 0.85, green: 0.1, blue: 0.1, alpha: 1))
            ctx.fill(CGRect(x: CGFloat(x) + 60 + hx - 6, y: groundY - 3, width: 12, height: 3))
        }
        ctx.setStrokeColor(CGColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.move(to: CGPoint(x: x + 4, y: Int(groundY))); ctx.addLine(to: CGPoint(x: x + cw - 4, y: Int(groundY))); ctx.strokePath()
        if let img = img { ctx.draw(img, in: CGRect(x: x, y: y, width: cw, height: ch)) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSAttributedString(string: label, attributes: [.font: NSFont.systemFont(ofSize: 9)]).draw(at: CGPoint(x: x + 3, y: y + ch - 12))
        NSGraphicsContext.restoreGraphicsState()
    }
    if let img = ctx.makeImage(), let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

/// Zkouška bez obrazovky: jezevcik --sim pad|pamlsky
func simulate(_ what: String) {
    _ = NSApplication.shared
    DogRenderer.load()
    let env = Env()
    let fx = Effects(scale: 2)
    fx.px = 2
    var cfg = Config(); cfg.size = 80; cfg.mischief = false; cfg.windowPlatforms = false
    let pet = Pet(cfg: cfg, env: env, fx: fx)
    pet.pixel = 2
    let mid = (env.dockL + env.dockR) / 2
    let inp = Input(mouse: CGPoint(x: -9999, y: -9999), typing: false)
    var treat: CGPoint?
    var simMouse = CGPoint(x: -9999, y: -9999)
    if what == "padak" {
        pet.mode = .grab
        pet.pos = CGPoint(x: mid, y: env.screen.frame.maxY - 150)
        pet.release()
        var shots: [CGImage] = []
        var tt: CGFloat = 0, nx: CGFloat = 0
        while tt < 30 && (pet.mode == .parachute || shots.count < 3) {
            pet.update(1.0 / 60, inp); tt += 1.0 / 60
            if tt >= nx { nx += 1.5; if let im = DogRenderer.sprite(pose: pet.buildPose(), scale: pet.s, facing: pet.facing, side: 240, px: 2) { shots.append(im) } }
            if pet.mode != .parachute && shots.count > 0 { break }
        }
        print(String(format: "padák: %.1f s, přistála: %@ %@, y nad zemí %.0f", tt, "\(pet.mode)", "\(pet.act)", pet.pos.y - env.floorY))
        let cw = 120
        if let ctx = CGContext(data: nil, width: cw * shots.count, height: cw, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.95, blue: 0.97, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: cw * shots.count, height: cw))
            ctx.interpolationQuality = .none
            for (i, im) in shots.enumerated() { ctx.draw(im, in: CGRect(x: i * cw, y: 0, width: cw, height: cw)) }
            if let img = ctx.makeImage(), let d = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:]) {
                try? d.write(to: URL(fileURLWithPath: NSTemporaryDirectory() + "padak.png"))
            }
        }
        return
    }
    if what == "micek" {
        pet.mode = .ground
        pet.pos = CGPoint(x: mid, y: env.floorY + DogRenderer.ground * pet.s)
        pet.setAct(.sit, 30)
        simMouse = CGPoint(x: mid - 150, y: env.floorY + 200)
        pet.throwBall(from: CGPoint(x: mid + 250, y: env.floorY + 400), vel: CGPoint(x: -150, y: 250))
    } else if what == "dest" {
        pet.mode = .ground
        pet.pos = CGPoint(x: mid, y: env.floorY + DogRenderer.ground * pet.s)
        pet.setAct(.sit, 30)
        pet.rainTreats()
    } else if what == "pamlsek" {
        pet.mode = .ground
        pet.pos = CGPoint(x: mid, y: env.floorY + DogRenderer.ground * pet.s)
        pet.setAct(.sit, 30)
        treat = CGPoint(x: mid + 200, y: env.floorY + 300)
        fx.holdTreat(at: treat!)
        pet.heldTreatPos = treat
        pet.fetchTreat()
    } else if what == "pelisek" || what == "veverka" {
        pet.mode = .ground
        pet.pos = CGPoint(x: mid, y: env.floorY + DogRenderer.ground * pet.s)
        pet.setAct(.sit, 30)
        if what == "pelisek" {
            pet.bedSpot = CGPoint(x: env.dockR + 70, y: env.screen.frame.minY + 14)
            pet.bedToggle()
        } else {
            pet.cfg.walkSpeed = 0.6
            pet.startEgg(1)
        }
    } else if what == "pad" {
        pet.pos = CGPoint(x: mid, y: env.floorY + 600)
        pet.startAir(v: CGPoint(x: 200, y: 0))
    } else {
        pet.mode = .ground
        pet.pos = CGPoint(x: mid, y: env.floorY + DogRenderer.ground * pet.s)
        pet.setAct(.sit, 30)
        pet.giveTreat(CGPoint(x: mid + 300, y: 900))
        pet.giveTreat(CGPoint(x: mid - 250, y: 700))
    }
    var t: CGFloat = 0, next: CGFloat = 0
    let total: CGFloat = what == "pelisek" ? 16 : 9
    while t < total {
        pet.update(1.0 / 60, what == "micek" ? Input(mouse: simMouse, typing: false) : inp)
        fx.update(1.0 / 60, floorY: env.floorY)
        t += 1.0 / 60
        if what == "pelisek" && t >= 12 && t - 1.0 / 60 < 12 { pet.bedToggle() }
        if what == "pamlsek" {
            if t >= 6 && treat != nil { treat = CGPoint(x: mid + 200, y: env.floorY + 70) }
            if fx.hasHeldTreat, let tr = treat { fx.moveHeld(to: tr); pet.heldTreatPos = tr } else { pet.heldTreatPos = nil }
        }
        if t >= next {
            next += 0.25
            let f = pet.buildPose().frame
            if what == "micek", let b = pet.ball { print(String(format: "   míček: x=%.0f y=%.0f %@ faze=%d", b.pos.x - mid, b.pos.y - env.floorY, b.carried ? "v tlamě" : (b.onGround ? "leží" : "letí"), pet.ballPhase)) }
            if what == "dest" { print("   pamlsky:", fx.sausages.map { String(format: "(%.0f,%.0f%@)", $0.pos.x - mid, $0.pos.y - env.floorY, $0.landed ? " leží" : "") }.joined(separator: " ")) }
            print(String(format: "%.2f %@ %@ f%d x=%.0f y=%.0f v=%.0f yOff=%.0f frame=%@ pamlsky=%d", t, "\(pet.mode)", "\(pet.act)", pet.fetchPhase, pet.pos.x - mid, pet.pos.y - env.floorY, pet.speedNow, pet.yOff, f, fx.sausages.count))
        }
    }
}

let args = CommandLine.arguments
if args.count >= 2 && args[1] == "--test" {
    exit(runSelfTest() ? 0 : 1)
}
if args.count >= 2 && args[1] == "--hotkeytest" {
    // zkouška: když už zkratku drží běžící Julie, systém druhou registraci odmítne (-9878)
    _ = NSApplication.shared
    var ref: EventHotKeyRef?
    let st = RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey), EventHotKeyID(signature: OSType(0x4A554C49), id: 1), GetApplicationEventTarget(), 0, &ref)
    print("RegisterEventHotKey: \(st)")
    exit(0)
}
if args.count >= 3 && args[1] == "--sim" {
    simulate(args[2])
    exit(0)
}
if args.count >= 3 && args[1] == "--nora" {
    renderBurrow(to: args[2])
    exit(0)
}
if args.count >= 2 && args[1] == "--mereni" {
    // Julie --mereni [od hodiny] [počet hodin]: simulovaný den bez člověka a jeho souhrn
    zmerDen(od: args.count >= 3 ? Double(args[2]) ?? 8 : 8, hodin: args.count >= 4 ? Double(args[3]) ?? 8 : 8)
    exit(0)
}
if args.count >= 4 && args[1] == "--ukazka" {
    exit(natocUkazku(args[2], do: args[3]) ? 0 : 1)
}
if args.count >= 3 && args[1] == "--sheet" {
    renderSheet(to: args[2])
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
app.delegate = controller
app.run()
