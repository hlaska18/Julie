import Cocoa
import Metal
import QuartzCore
import ImageIO
import UniformTypeIdentifiers

/// Ukázky pro web a README: `Julie --ukazka <scéna> <složka>` uloží snímky PNG (25 za vteřinu),
/// GIF z nich složí tools/ukazky.py. Nahrává se skutečná Julie – stejný kód, fyzika i efekty jako
/// na ploše. Vrstvy kreslí CARenderer do textury Metalu (bez obrazovky a bez nahrávání obrazovky);
/// scéna běží v reálném čase, aby animace vrstev (štěkání, hlína, srdíčka) seděly s pohybem Julie.
/// Dock je jen obecný pruh s barevnými čtverečky (žádné skutečné ikony).
let ukazkoveSceny = ["chuze", "nora", "pamlsky", "micek", "pelisek", "padak", "veverka", "hlazeni"]

func natocUkazku(_ scena: String, do slozka: String) -> Bool {
    _ = NSApplication.shared
    DogRenderer.load()
    guard ukazkoveSceny.contains(scena) else {
        print("Neznámá scéna. Možnosti: " + ukazkoveSceny.joined(separator: ", ")); return false
    }
    // rozměry obrázku a Docku (v bodech = pixelech GIFu)
    let vysoka = scena == "padak"
    let W: CGFloat = 560                 // na webu dva sloupce po 560 px, zobrazené 1 : 1
    let H: CGFloat = vysoka ? 340 : 200
    let floorY: CGFloat = 76
    let (dockL, dockR): (CGFloat, CGFloat) = {
        switch scena {
        case "pelisek": return (40, 360)
        case "padak": return (40, 520)
        default: return (40, 520)
        }
    }()

    let env = Env()
    env.left = 0; env.right = W; env.ceilY = H; env.floorY = floorY
    env.dockL = dockL; env.dockR = dockR
    env.dockAvailable = true

    var cfg = Config()
    cfg.size = 100; cfg.mischief = false; cfg.windowPlatforms = false; cfg.eyeTracking = false
    cfg.claudeWatch = false
    let px = max(2, (CGFloat(cfg.size) / 38).rounded())
    let side = (CGFloat(cfg.size) * 3.0 / px).rounded() * px
    let fx = Effects(scale: 1)
    fx.px = px
    fx.dogLayer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
    fx.root.frame = CGRect(x: 0, y: 0, width: W, height: H)
    fx.treatRange = (dockL + 20)...(dockR - 20)
    let pet = Pet(cfg: cfg, env: env, fx: fx)
    pet.pixel = px

    // pozadí: plocha a Dock
    let scene = CALayer()
    scene.frame = CGRect(x: 0, y: 0, width: W, height: H)
    // barvy podle palety Minty Fresh z coolors.co (stejné jako na webu)
    func hex(_ v: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
    scene.backgroundColor = hex(0xE6DDC8)
    let pill = CALayer()
    pill.frame = CGRect(x: dockL - 10, y: 6, width: dockR - dockL + 20, height: floorY - 6)
    pill.backgroundColor = hex(0xFFFFFF)
    pill.borderColor = hex(0xC4B590)
    pill.borderWidth = 1
    pill.cornerRadius = 18
    scene.addSublayer(pill)
    let barvy: [UInt32] = [0x19535F, 0x0B7A75, 0x7B2D26, 0xD7C9AA]
    let ikona: CGFloat = 52, mezera: CGFloat = 8
    let pocet = Int((dockR - dockL + mezera) / (ikona + mezera))
    let zacatek = dockL + (dockR - dockL - CGFloat(pocet) * (ikona + mezera) + mezera) / 2
    for i in 0..<pocet {
        let l = CALayer()
        l.frame = CGRect(x: zacatek + CGFloat(i) * (ikona + mezera), y: 15, width: ikona, height: ikona)
        l.backgroundColor = hex(barvy[i % barvy.count])
        l.cornerRadius = 12
        scene.addSublayer(l)
    }
    scene.addSublayer(fx.root)
    // kurzor (jen ve scéně s míčkem)
    let kurzor = CALayer()
    kurzor.contents = kurzorObrazek()
    kurzor.bounds = CGRect(x: 0, y: 0, width: 14, height: 21)
    kurzor.anchorPoint = CGPoint(x: 0.1, y: 0.95)     // špička šipky
    kurzor.magnificationFilter = .nearest
    kurzor.isHidden = true
    scene.addSublayer(kurzor)

    // Metal + CARenderer
    guard let dev = MTLCreateSystemDefaultDevice(), let fronta = dev.makeCommandQueue() else { print("Metal není k dispozici"); return false }
    let popis = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(W), height: Int(H), mipmapped: false)
    popis.usage = [.renderTarget, .shaderRead]
    popis.storageMode = dev.hasUnifiedMemory ? .shared : .managed
    guard let tex = dev.makeTexture(descriptor: popis) else { return false }
    let renderer = CARenderer(mtlTexture: tex, options: [kCARendererColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                         kCARendererMetalCommandQueue: fronta])
    renderer.layer = scene
    renderer.bounds = scene.frame

    try? FileManager.default.createDirectory(atPath: slozka, withIntermediateDirectories: true)

    // výchozí stav
    pet.mode = .ground
    pet.surfaceId = 0
    pet.pos = CGPoint(x: dockL + 160, y: floorY + DogRenderer.ground * pet.s)
    pet.facing = 1
    pet.setAct(.sit, 99)
    var mys = CGPoint(x: -9999, y: -9999)
    var konec: CGFloat = 12          // nejdéle
    var dobeh: CGFloat = -1          // čas, kdy se scéna začala dobíhat (pak ještě chvíli běží)
    var udalost = 0

    switch scena {
    case "nora":
        pet.pos.x = (dockL + dockR) / 2 - 60
    case "pelisek":
        pet.pos.x = dockL + 120
        let b = fx.bedSize
        pet.bedSpot = CGPoint(x: dockR + 10 + 14 + b.width / 2, y: (floorY - b.height) / 2)
    case "padak":
        pet.pos = CGPoint(x: 150, y: H - 40)
        pet.startParachute(CGPoint(x: 90, y: 0))
    case "veverka":
        pet.pos.x = dockL + 120
        pet.cfg.walkSpeed = 0.6
    case "micek":
        pet.pos.x = dockL + 360
        pet.facing = -1
        kurzor.isHidden = false
        mys = CGPoint(x: dockL + 90, y: floorY + 95)
    case "hlazeni":
        pet.pos.x = (dockL + dockR) / 2 - 40
        kurzor.isHidden = false
        mys = CGPoint(x: dockR - 60, y: floorY + 110)
    default: break
    }
    // hlazení: stejné rozpoznání jako v AppController.tick (sem a tam po Julii)
    var tahSoucet: CGFloat = 0, tahObratu = 0, tahSmer: CGFloat = 0
    var predchoziMys = mys
    let mysStart = mys

    if scena == "pamlsky" { konec = 30 }
    let fps: CGFloat = 25, dt = 1 / fps
    var t: CGFloat = 0
    var snimek = 0
    let start = CACurrentMediaTime()
    var vsePrislo = false
    while t < konec {
        // scénář
        switch scena {
        case "chuze":
            let plan: [(CGFloat, () -> Void)] = [
                (0.0, { pet.setAct(.walk, 99); pet.walkDir = 1 }),
                (2.6, { pet.setAct(.sniff, 99) }),
                (3.8, { pet.setAct(.bark, 99) }),
                (5.1, { pet.setAct(.sit, 99) }),
                (6.0, { pet.setAct(.scratch, 99) }),
                (7.4, { pet.setAct(.walk, 99); pet.walkDir = -1 }),
                (9.6, { pet.setAct(.stretch, 99) }),
                (10.9, { pet.setAct(.sit, 99) })]
            konec = 11.6
            while udalost < plan.count && t >= plan[udalost].0 { plan[udalost].1(); udalost += 1 }
        case "nora":
            if udalost == 0 && t >= 0.4 { pet.setAct(.dig, 1); udalost = 1 }
            if udalost == 1 && pet.act != .dig && dobeh < 0 { dobeh = t }
        case "pamlsky":
            if udalost == 0 && t >= 0.3 { pet.rainTreats(); udalost = 1 }
            if udalost == 1 && pet.act != .sausage && fx.sausages.isEmpty && dobeh < 0 { dobeh = t }
        case "micek":
            if udalost == 0 && t >= 0.3 { pet.holdBall(at: mys); udalost = 1 }
            if udalost == 1 && t < 1.0 { pet.holdBall(at: mys) }
            if udalost == 1 && t >= 1.0 { pet.throwBall(from: mys, vel: CGPoint(x: 380, y: 330)); udalost = 2 }
            if udalost == 2 && pet.act == .fetchBall && pet.ballPhase == 2 && dobeh < 0 { dobeh = t }
        case "pelisek":
            if udalost == 0 && t >= 0.5 { pet.bedToggle(); udalost = 1 }
            if udalost == 1 && pet.act == .inBed { udalost = 2; dobeh = t + 3.2 }   // poleží si a pak ji vzbudíme
            if udalost == 2 && t >= dobeh { pet.bedToggle(); udalost = 3; dobeh = -1 }
            if udalost == 3 && [.stretch, .walk, .sit].contains(pet.act) && dobeh < 0 { dobeh = t }
        case "padak":
            if pet.mode == .ground && ![.shake, .dizzy].contains(pet.act) && dobeh < 0 { dobeh = t }
        case "veverka":
            if udalost == 0 && t >= 0.4 { pet.startEgg(1); udalost = 1 }
            if udalost == 1 && pet.act != .squirrel && dobeh < 0 { dobeh = t }
        case "hlazeni":
            // kurzor dojede nad hřbet, pak přejíždí sem a tam, nakonec odjede
            let r = pet.hitRect
            let hrbet = CGPoint(x: r.midX, y: r.minY + r.height * 0.62)
            if t < 0.9 {
                let u = t / 0.9, e = u * u * (3 - 2 * u)
                mys = CGPoint(x: mysStart.x + (hrbet.x - mysStart.x) * e, y: mysStart.y + (hrbet.y - mysStart.y) * e)
            } else if t < 5.0 {
                // jako skutečné hlazení: rychle a přes celý hřbet (aplikace ho pozná až po 160 bodech tahů)
                let f = (t - 0.9) * 2 * .pi * 1.7
                mys = CGPoint(x: hrbet.x + sin(f) * min(42, r.width * 0.4), y: hrbet.y + cos(f * 2) * 2)
            } else {
                let u = min(1, (t - 5.0) / 0.9), e = u * u * (3 - 2 * u)
                mys = CGPoint(x: hrbet.x + (mysStart.x - hrbet.x) * e, y: hrbet.y + (mysStart.y - hrbet.y) * e)
            }
            tahSoucet *= exp(-dt * 1.2)
            if r.contains(mys) {
                let dx = mys.x - predchoziMys.x
                if dx != 0 && (dx > 0) != (tahSmer > 0) { tahObratu += 1 }
                if abs(dx) > 0.5 { tahSmer = dx }
                tahSoucet += abs(dx)
                if tahSoucet > 160 && tahObratu >= 2 { pet.petted(); tahSoucet = 60; udalost = 1 }
            } else {
                tahObratu = 0
            }
            predchoziMys = mys
            if udalost == 1 && t > 5.0 && ![.petted, .shake].contains(pet.act) && dobeh < 0 { dobeh = t }
            if t > 11 && dobeh < 0 { dobeh = t }
        default: break
        }
        if scena != "chuze" && scena != "pelisek" && dobeh >= 0 && !vsePrislo { vsePrislo = true; konec = dobeh + 1.4 }
        if scena == "pelisek" && udalost == 3 && dobeh >= 0 && !vsePrislo { vsePrislo = true; konec = dobeh + 1.2 }

        // krok simulace a vykreslení (jako AppController.tick + render)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        Pet.step(pet, fx, dt, Input(mouse: mys, typing: false), floorY: env.floorY)
        let p = pet.buildPose().quantized()
        fx.dogLayer.contents = DogRenderer.sprite(pose: p, scale: pet.s, facing: pet.facing, side: side, px: px)
        let cx = pet.pos.x, cy = pet.pos.y + pet.yOff
        fx.dogLayer.position = CGPoint(x: ((cx - side / 2) / px).rounded() * px + side / 2,
                                       y: ((cy - side / 2) / px).rounded() * px + side / 2)
        fx.setBed(bottom: pet.bedSpot, inside: pet.act == .inBed && pet.mode == .ground)
        let vTlame = pet.ball?.carried == true && p.frame.hasPrefix("mic_")
        fx.setBall(vTlame ? nil : pet.ball?.pos)
        kurzor.position = mys
        CATransaction.commit()
        CATransaction.flush()

        // počkat na skutečný čas snímku (animace vrstev běží podle hodin) a mezitím obsloužit
        // odložené úklidy efektů (DispatchQueue.main.asyncAfter)
        t += dt
        let cil = start + CFTimeInterval(t)
        while CACurrentMediaTime() < cil {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: max(0.001, cil - CACurrentMediaTime())))
        }

        renderer.beginFrame(atTime: CACurrentMediaTime(), timeStamp: nil)
        renderer.addUpdate(renderer.bounds)
        renderer.render()
        renderer.endFrame()
        if let cb = fronta.makeCommandBuffer() {
            if !dev.hasUnifiedMemory, let blit = cb.makeBlitCommandEncoder() { blit.synchronize(resource: tex); blit.endEncoding() }
            cb.commit(); cb.waitUntilCompleted()
        }
        if let img = obrazekZTextury(tex, sirka: Int(W), vyska: Int(H)) {
            ulozPNG(img, String(format: "%@/%04d.png", slozka, snimek))
        }
        snimek += 1
    }
    print("\(scena): \(snimek) snímků, \(String(format: "%.1f", t)) s")
    return true
}

/// Šipka kurzoru (obecný tvar), černá s bílým okrajem.
private func kurzorObrazek() -> CGImage? {
    let w = 14, h = 21
    guard let ctx = CGContext(data: nil, width: w * 2, height: h * 2, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: 2, y: 2)
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)      // kreslíme shora dolů
    let body: [CGPoint] = [CGPoint(x: 1.5, y: 1), CGPoint(x: 1.5, y: 16.5), CGPoint(x: 5.2, y: 13), CGPoint(x: 8, y: 19.2),
                           CGPoint(x: 10.6, y: 18), CGPoint(x: 7.9, y: 12), CGPoint(x: 12.6, y: 12)]
    ctx.addLines(between: body); ctx.closePath()
    ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(1.4); ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)
    return ctx.makeImage()
}

private func obrazekZTextury(_ tex: MTLTexture, sirka w: Int, vyska h: Int) -> CGImage? {
    var data = [UInt8](repeating: 0, count: w * h * 4)
    tex.getBytes(&data, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
    // CARenderer kreslí s počátkem vlevo dole, obrázek se čte shora: obrátit řádky
    let radek = w * 4
    for y in 0..<(h / 2) {
        let a = y * radek, b = (h - 1 - y) * radek
        for i in 0..<radek { data.swapAt(a + i, b + i) }
    }
    let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else { return nil }
    return ctx.makeImage()
}

private func ulozPNG(_ img: CGImage, _ cesta: String) {
    guard let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: cesta) as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
}
