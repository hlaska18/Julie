import Cocoa
import QuartzCore

final class DogLayer: CALayer {
    var pose = DogPose()
    var sc: CGFloat = 1
    var facing: CGFloat = 1

    override init() { super.init() }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }
}

/// Bublina nad psem (bílá, zaoblená, s ocáskem dolů).
final class BubbleLayer: CALayer {
    private let bg = CAShapeLayer()
    private let tx = CATextLayer()
    private var current = ""

    override init() {
        super.init()
        anchorPoint = CGPoint(x: 0.5, y: 0)
        bg.fillColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.97)
        bg.strokeColor = CGColor(srgbRed: 0.05, green: 0.54, blue: 0.51, alpha: 1)
        bg.lineWidth = 1.5
        addSublayer(bg)
        tx.alignmentMode = .center
        tx.foregroundColor = CGColor(srgbRed: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        tx.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        tx.fontSize = 12.5
        tx.isWrapped = false
        addSublayer(tx)
        isHidden = true
    }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ text: String?, scale: CGFloat) {
        guard let text = text, !text.isEmpty else {
            isHidden = true
            current = ""
            return
        }
        isHidden = false
        if text == current { return }
        current = text
        contentsScale = scale
        tx.contentsScale = scale
        bg.contentsScale = scale
        let font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        let w = ceil((text as NSString).size(withAttributes: [.font: font]).width) + 20
        let h: CGFloat = 26
        let tail: CGFloat = 7
        bounds = CGRect(x: 0, y: 0, width: w, height: h + tail)
        let r = CGRect(x: 0.75, y: tail, width: w - 1.5, height: h - 0.75)
        let path = CGMutablePath()
        path.addRoundedRect(in: r, cornerWidth: 11, cornerHeight: 11)
        path.move(to: CGPoint(x: w / 2 - 6, y: tail + 0.5))
        path.addLine(to: CGPoint(x: w / 2, y: 0.5))
        path.addLine(to: CGPoint(x: w / 2 + 6, y: tail + 0.5))
        bg.path = path
        bg.frame = bounds
        tx.string = text
        tx.frame = CGRect(x: 0, y: tail + 5, width: w, height: 17)
    }
}

private final class Particle {
    let layer: CALayer
    var vel: CGPoint
    var life: CGFloat
    var maxLife: CGFloat
    var gravity: CGFloat
    init(layer: CALayer, vel: CGPoint, life: CGFloat, gravity: CGFloat) {
        self.layer = layer; self.vel = vel; self.life = life; self.maxLife = life; self.gravity = gravity
    }
}

final class Sausage {
    let layer: CALayer
    var pos: CGPoint
    var vel: CGPoint
    var rot: CGFloat = 0
    var spin: CGFloat
    var landed = false
    var age: CGFloat = 0
    init(layer: CALayer, pos: CGPoint, vel: CGPoint, spin: CGFloat) {
        self.layer = layer; self.pos = pos; self.vel = vel; self.spin = spin
    }
}

final class Effects {
    var treatRange: ClosedRange<CGFloat>?   // pamlsky smí dopadnout jen nad Dock
    let root = CALayer()
    let under = CALayer()      // díry, šlápoty
    let dogLayer = DogLayer()
    let over = CALayer()       // částice, emoji
    let bubble = BubbleLayer()
    var scale: CGFloat
    private var particles: [Particle] = []
    private(set) var sausages: [Sausage] = []
    private var squirrel: CALayer?
    var px: CGFloat = 2
    private(set) var squirrelPos: CGPoint = .zero
    private var pawImage: CGImage?

    init(scale: CGFloat) {
        self.scale = scale
        root.addSublayer(under)
        root.addSublayer(dogLayer)
        root.addSublayer(over)
        root.addSublayer(bubble)
        dogLayer.contentsScale = scale
        dogLayer.magnificationFilter = .nearest
        dogLayer.minificationFilter = .nearest
        dogLayer.drawsAsynchronously = false
        dogLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    // MARK: pomocné

    private func textLayer(_ s: String, size: CGFloat, color: CGColor? = nil) -> CATextLayer {
        let t = CATextLayer()
        t.string = s
        t.fontSize = size
        t.alignmentMode = .center
        t.contentsScale = scale
        t.bounds = CGRect(x: 0, y: 0, width: size * 2.2, height: size * 1.35)
        if let c = color { t.foregroundColor = c }
        return t
    }

    /// Text/emoji, který vyplave nahoru a zmizí.
    func floatText(_ s: String, at p: CGPoint, size: CGFloat = 22, rise: CGFloat = 55, dx: CGFloat = 0, dur: CFTimeInterval = 1.5, color: CGColor? = nil) {
        let t = textLayer(s, size: size, color: color ?? CGColor(srgbRed: 0.1, green: 0.1, blue: 0.12, alpha: 1))
        t.position = p
        over.addSublayer(t)
        let m = CABasicAnimation(keyPath: "position")
        m.fromValue = NSValue(point: p)
        m.toValue = NSValue(point: CGPoint(x: p.x + dx, y: p.y + rise))
        let f = CAKeyframeAnimation(keyPath: "opacity")
        f.values = [0, 1, 1, 0]
        f.keyTimes = [0, 0.12, 0.65, 1]
        let g = CAAnimationGroup()
        g.animations = [m, f]
        g.duration = dur
        g.isRemovedOnCompletion = false
        g.fillMode = .forwards
        t.add(g, forKey: "float")
        DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.05) { t.removeFromSuperlayer() }
    }

    private let dirtColors: [CGColor] = [
        CGColor(srgbRed: 0.36, green: 0.22, blue: 0.12, alpha: 1),
        CGColor(srgbRed: 0.48, green: 0.31, blue: 0.17, alpha: 1),
        CGColor(srgbRed: 0.27, green: 0.16, blue: 0.08, alpha: 1)]

    /// Hroudy hlíny jako čtverečky v mřížce pixel artu.
    func dirt(at p: CGPoint, dir: CGFloat, sizeScale: CGFloat, px: CGFloat) {
        for _ in 0..<2 {
            let l = CALayer()
            let d = px * CGFloat(Int.random(in: 1...2))
            l.bounds = CGRect(x: 0, y: 0, width: d, height: d)
            l.backgroundColor = dirtColors.randomElement()!
            l.position = p
            over.addSublayer(l)
            let v = CGPoint(x: -dir * CGFloat.random(in: 50...170) * sizeScale, y: CGFloat.random(in: 150...320) * sizeScale)
            particles.append(Particle(layer: l, vel: v, life: 0.7, gravity: 900 * max(0.5, sizeScale)))
        }
    }

    /// Hrouda letí obloukem pod Julií dozadu a dopadne na kupku za ní.
    func dirtArc(from p: CGPoint, to x: CGFloat, floorY: CGFloat, px: CGFloat) {
        let l = CALayer()
        let d = px * CGFloat(Int.random(in: 1...2))
        l.bounds = CGRect(x: 0, y: 0, width: d, height: d)
        l.backgroundColor = dirtColors.randomElement()!
        l.position = p
        over.addSublayer(l)
        let dur = CGFloat.random(in: 0.35...0.55)
        let g: CGFloat = 1400 * px / 2
        let vx = (x - p.x) / dur
        let vy = ((floorY + px) - p.y + 0.5 * g * dur * dur) / dur
        particles.append(Particle(layer: l, vel: CGPoint(x: vx, y: vy), life: dur, gravity: g))
    }

    private var moundImage: CGImage?

    /// Kupka vyhrabané hlíny (pixel art).
    private func moundGlyph() -> CGImage? {
        if let m = moundImage { return m }
        let rows = ["....aaab....",
                    "..aabaaaba..",
                    ".abaaacaaab.",
                    "aaacaaaabaac"]
        let w = rows[0].count, h = rows.count
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for (r, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                switch ch {
                case "a": ctx.setFillColor(dirtColors[1])
                case "b": ctx.setFillColor(dirtColors[0])
                case "c": ctx.setFillColor(dirtColors[2])
                default: continue
                }
                ctx.fill(CGRect(x: x, y: h - 1 - r, width: 1, height: 1))
            }
        }
        moundImage = ctx.makeImage()
        return moundImage
    }

    func mound(at x: CGFloat, floorY: CGFloat, px: CGFloat, grow: CFTimeInterval) {
        let l = CALayer()
        l.contents = moundGlyph()
        l.magnificationFilter = .nearest
        l.bounds = CGRect(x: 0, y: 0, width: 12 * px, height: 4 * px)
        l.anchorPoint = CGPoint(x: 0.5, y: 0)
        l.position = CGPoint(x: (x / px).rounded() * px, y: floorY)
        under.addSublayer(l)
        let g = CABasicAnimation(keyPath: "transform.scale")
        g.fromValue = 0.1; g.toValue = 1; g.duration = grow
        l.add(g, forKey: "grow")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0; fade.beginTime = CACurrentMediaTime() + 9; fade.duration = 2
        fade.fillMode = .forwards; fade.isRemovedOnCompletion = false
        l.add(fade, forKey: "fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 11.2) { l.removeFromSuperlayer() }
    }

    private var holeImage: CGImage?

    /// Pixelová díra: tmavý otvor s vyhrnutou hlínou kolem.
    private func holeGlyph() -> CGImage? {
        if let h = holeImage { return h }
        let w = 24, h = 7
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setShouldAntialias(false)
        // vyhrnutá hlína (val)
        ctx.setFillColor(dirtColors[1])
        ctx.fillEllipse(in: CGRect(x: 0, y: 1, width: 24, height: 6))
        ctx.setFillColor(dirtColors[0])
        ctx.fill(CGRect(x: 1, y: 3, width: 3, height: 2)); ctx.fill(CGRect(x: 20, y: 3, width: 3, height: 2))
        // otvor
        ctx.setFillColor(CGColor(srgbRed: 0.13, green: 0.07, blue: 0.04, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 4, y: 1, width: 16, height: 4))
        holeImage = ctx.makeImage()
        return holeImage
    }

    func hole(at x: CGFloat, floorY: CGFloat, px: CGFloat, grow: CFTimeInterval) {
        let l = CALayer()
        l.contents = holeGlyph()
        l.magnificationFilter = .nearest
        l.bounds = CGRect(x: 0, y: 0, width: 24 * px, height: 7 * px)
        l.anchorPoint = CGPoint(x: 0.5, y: 3.0 / 7.0)
        l.position = CGPoint(x: (x / px).rounded() * px, y: floorY)
        under.addSublayer(l)
        let g = CABasicAnimation(keyPath: "transform.scale.x")
        g.fromValue = 0.15; g.toValue = 1; g.duration = grow
        l.add(g, forKey: "grow")
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0; fade.beginTime = CACurrentMediaTime() + 9; fade.duration = 2
        fade.fillMode = .forwards; fade.isRemovedOnCompletion = false
        l.add(fade, forKey: "fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 11.2) { l.removeFromSuperlayer() }
    }

    private func pawGlyph() -> CGImage? {
        if let p = pawImage { return p }
        let w = 24, h = 24
        guard let ctx = CGContext(data: nil, width: w * 2, height: h * 2, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: 2, y: 2)
        ctx.setFillColor(CGColor(srgbRed: 0.24, green: 0.11, blue: 0.04, alpha: 0.55))
        ctx.fillEllipse(in: CGRect(x: 6, y: 2, width: 12, height: 10))
        for (x, y) in [(2.0, 11.0), (7.5, 15.0), (13.5, 15.0), (18.5, 11.0)] as [(CGFloat, CGFloat)] {
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: 4.2, height: 5))
        }
        pawImage = ctx.makeImage()
        return pawImage
    }

    func paw(at p: CGPoint, size: CGFloat, facing: CGFloat) {
        let l = CALayer()
        l.contents = pawGlyph()
        l.contentsScale = scale
        l.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        l.position = p
        l.setAffineTransform(CGAffineTransform(rotationAngle: -facing * 1.4))
        under.addSublayer(l)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0; fade.duration = 4
        fade.fillMode = .forwards; fade.isRemovedOnCompletion = false
        l.add(fade, forKey: "fade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.1) { l.removeFromSuperlayer() }
    }

    // MARK: štěkání

    private var waveImage: CGImage?

    private func waveGlyph() -> CGImage? {
        if let w = waveImage { return w }
        let w = 12, h = 16
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setShouldAntialias(false)
        ctx.setAllowsAntialiasing(false)
        ctx.setLineCap(.square)
        for (r, a) in [(4.5, 0.75), (8.5, 0.75)] as [(CGFloat, CGFloat)] {
            for (col, lw) in [(CGColor(srgbRed: 0.29, green: 0.13, blue: 0.05, alpha: 1), CGFloat(3)),
                              (CGColor(srgbRed: 1, green: 0.97, blue: 0.9, alpha: 1), CGFloat(1))] {
                ctx.setStrokeColor(col)
                ctx.setLineWidth(lw)
                ctx.addArc(center: CGPoint(x: 0.5, y: 8), radius: r, startAngle: -a, endAngle: a, clockwise: false)
                ctx.strokePath()
            }
        }
        waveImage = ctx.makeImage()
        return waveImage
    }

    func barkWaves(at p: CGPoint, facing: CGFloat, px: CGFloat) {
        let l = CALayer()
        l.contents = waveGlyph()
        l.magnificationFilter = .nearest
        l.bounds = CGRect(x: 0, y: 0, width: 12 * px, height: 16 * px)
        l.anchorPoint = CGPoint(x: 0, y: 0.5)
        l.position = p
        if facing < 0 { l.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
        over.addSublayer(l)
        let m = CABasicAnimation(keyPath: "position.x")
        m.fromValue = p.x; m.toValue = p.x + facing * 8 * px
        let f = CABasicAnimation(keyPath: "opacity")
        f.fromValue = 1; f.toValue = 0
        let g = CAAnimationGroup()
        g.animations = [m, f]; g.duration = 0.45
        g.isRemovedOnCompletion = false; g.fillMode = .forwards
        l.add(g, forKey: "w")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { l.removeFromSuperlayer() }
    }

    // MARK: meteory

    func meteor(screenW: CGFloat, screenH: CGFloat) {
        let l = CAShapeLayer()
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: -110, y: 70))
        l.path = path
        l.strokeColor = CGColor(srgbRed: 1, green: 0.95, blue: 0.7, alpha: 0.95)
        l.lineWidth = 2.6
        l.lineCap = .round
        l.shadowColor = CGColor(srgbRed: 1, green: 0.9, blue: 0.5, alpha: 1)
        l.shadowOpacity = 1; l.shadowRadius = 5; l.shadowOffset = .zero
        let start = CGPoint(x: CGFloat.random(in: screenW * 0.25...screenW * 1.0), y: screenH - CGFloat.random(in: 60...220))
        let end = CGPoint(x: start.x - 520, y: start.y - 340)
        l.position = start
        over.addSublayer(l)
        let m = CABasicAnimation(keyPath: "position")
        m.fromValue = NSValue(point: start); m.toValue = NSValue(point: end)
        let f = CAKeyframeAnimation(keyPath: "opacity")
        f.values = [0, 1, 1, 0]; f.keyTimes = [0, 0.1, 0.7, 1]
        let g = CAAnimationGroup()
        g.animations = [m, f]; g.duration = 1.1
        g.isRemovedOnCompletion = false; g.fillMode = .forwards
        l.add(g, forKey: "m")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { l.removeFromSuperlayer() }
    }

    // MARK: párky

    /// Pixelový sprite (snímek z Higgsfieldu) jako vrstva, `flip` = zrcadlově.
    private func spriteLayer(_ name: String, flip: Bool = false) -> CALayer {
        let l = CALayer()
        let img = DogRenderer.frames[name]
        l.contents = img
        l.magnificationFilter = .nearest
        l.bounds = CGRect(x: 0, y: 0, width: CGFloat(img?.width ?? 10) * px, height: CGFloat(img?.height ?? 10) * px)
        if flip { l.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
        return l
    }

    func dropSausage(x: CGFloat, y: CGFloat, size: CGFloat) {
        let l = spriteLayer(Effects.randomTreat(), flip: Bool.random())
        l.position = CGPoint(x: x, y: y)
        over.addSublayer(l)
        sausages.append(Sausage(layer: l, pos: CGPoint(x: x, y: y), vel: CGPoint(x: CGFloat.random(in: -30...30), y: 0), spin: 0))
    }

    // MARK: pamlsek v ruce (u kurzoru)

    private var held: CALayer?
    private var heldName = "susenka0"

    /// Psí sušenka ve tvaru kosti (tři barvy); bez snímků z Higgsfieldu aspoň kost.
    static func randomTreat() -> String {
        let all = ["susenka0", "susenka1", "susenka2"].filter { DogRenderer.frames[$0] != nil }
        return all.randomElement() ?? "kost"
    }
    var hasHeldTreat: Bool { held != nil }
    /// Pamlsek je kousek vpravo pod hrotem kurzoru.
    static let heldOffset = CGPoint(x: 16, y: -18)

    func holdTreat(at p: CGPoint) {
        heldName = Effects.randomTreat()
        let l = spriteLayer(heldName)
        over.addSublayer(l)
        held = l
        moveHeld(to: p)
    }

    func moveHeld(to p: CGPoint) {
        held?.position = CGPoint(x: (p.x / px).rounded() * px, y: (p.y / px).rounded() * px)
    }

    /// Julie ho vzala z ruky.
    func takeHeld() {
        held?.removeFromSuperlayer()
        held = nil
    }

    /// Pustíš ho: spadne na Dock jako obyčejný pamlsek.
    func dropHeld() {
        guard let l = held else { return }
        let p = l.position
        l.removeFromSuperlayer()
        held = nil
        let f = spriteLayer(heldName)
        f.position = p
        over.addSublayer(f)
        sausages.append(Sausage(layer: f, pos: p, vel: .zero, spin: 0))
    }

    /// Sní první pamlsek v dosahu, vrací počet.
    func eat(_ target: Sausage) {
        target.layer.removeFromSuperlayer()
        sausages.removeAll { $0 === target }
    }

    func eatSausage(near p: CGPoint, radius: CGFloat) -> Int {
        var n = 0
        sausages.removeAll { s in
            if hypot(s.pos.x - p.x, s.pos.y - p.y) < radius {
                s.layer.removeFromSuperlayer()
                n += 1
                return true
            }
            return false
        }
        return n
    }

    // MARK: pelíšek

    private let bedBack = CALayer()
    private let bedFront = CALayer()
    private var bedReady = false
    /// Od kterého řádku (podíl výšky shora) je přední okraj pelíšku, který Julii překryje.
    static let bedFrontFrom: CGFloat = 0.5

    /// Kde pelíšek je (pro kliknutí myší).
    private(set) var bedRect = CGRect.zero
    var bedSize: CGSize {
        guard let img = DogRenderer.frames["pelisek"] else { return .zero }
        return CGSize(width: CGFloat(img.width) * px, height: CGFloat(img.height) * px)
    }

    /// Pelíšek stojí vedle Docku; `bottom` = střed spodní hrany. `inside` = Julie leží uvnitř (přední okraj přes ni).
    func setBed(bottom: CGPoint?, inside: Bool) {
        guard let img = DogRenderer.frames["pelisek"] else { return }
        if !bedReady {
            bedReady = true
            for l in [bedBack, bedFront] {
                l.magnificationFilter = .nearest
                l.anchorPoint = CGPoint(x: 0.5, y: 0)
            }
            bedBack.contents = img
            let from = Int((CGFloat(img.height) * Effects.bedFrontFrom).rounded())
            bedFront.contents = img.cropping(to: CGRect(x: 0, y: from, width: img.width, height: img.height - from))
            under.addSublayer(bedBack)
            over.insertSublayer(bedFront, at: 0)
        }
        guard let b = bottom else { bedBack.isHidden = true; bedFront.isHidden = true; bedRect = .zero; return }
        let w = CGFloat(img.width) * px, h = CGFloat(img.height) * px
        let from = (CGFloat(img.height) * Effects.bedFrontFrom).rounded()
        let pos = CGPoint(x: (b.x / px).rounded() * px, y: (b.y / px).rounded() * px)
        bedRect = CGRect(x: pos.x - w / 2, y: pos.y, width: w, height: h)
        bedBack.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        bedFront.bounds = CGRect(x: 0, y: 0, width: w, height: h - from * px)
        bedBack.position = pos
        bedFront.position = pos
        bedBack.isHidden = false
        bedFront.isHidden = !inside
    }

    // MARK: míček

    private let ballLayer = CALayer()
    private var ballReady = false
    private(set) var ballRect = CGRect.zero

    /// Pixelový tenisák (6×6).
    private func ballGlyph() -> CGImage? {
        let rows = [".abba.",
                    "abbcba",
                    "bcbbab",
                    "babbcb",
                    "abcbbd",
                    ".bddd."]
        guard let ctx = CGContext(data: nil, width: 6, height: 6, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for (r, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                switch ch {
                case "a": ctx.setFillColor(CGColor(srgbRed: 0.86, green: 0.92, blue: 0.36, alpha: 1))
                case "b": ctx.setFillColor(CGColor(srgbRed: 0.78, green: 0.86, blue: 0.20, alpha: 1))
                case "c": ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.97, blue: 0.86, alpha: 1))
                case "d": ctx.setFillColor(CGColor(srgbRed: 0.60, green: 0.68, blue: 0.14, alpha: 1))
                default: continue
                }
                ctx.fill(CGRect(x: x, y: 5 - r, width: 1, height: 1))
            }
        }
        return ctx.makeImage()
    }

    /// `p` = střed míčku; nil = žádný (nebo ho Julie nese v tlamě a je nakreslený ve snímku).
    func setBall(_ p: CGPoint?) {
        if !ballReady {
            ballReady = true
            ballLayer.contents = ballGlyph()
            ballLayer.magnificationFilter = .nearest
            over.addSublayer(ballLayer)
        }
        guard let p = p else { ballLayer.isHidden = true; ballRect = .zero; return }
        ballLayer.isHidden = false
        ballLayer.bounds = CGRect(x: 0, y: 0, width: 6 * px, height: 6 * px)
        ballLayer.position = CGPoint(x: (p.x / px).rounded() * px, y: (p.y / px).rounded() * px)
        ballRect = ballLayer.frame.insetBy(dx: -6, dy: -6)
    }

    // MARK: srdíčko (hlazení)

    private var heartImage: CGImage?

    private func heartGlyph() -> CGImage? {
        if let h = heartImage { return h }
        let rows = [".XX.XX.",
                    "XPPXPPX",
                    "XPWPPPX",
                    "XPPPPPX",
                    ".XPPPX.",
                    "..XPX..",
                    "...X..."]
        let w = 7, h = rows.count
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        for (r, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                switch ch {
                case "X": ctx.setFillColor(CGColor(srgbRed: 0.42, green: 0.09, blue: 0.16, alpha: 1))
                case "P": ctx.setFillColor(CGColor(srgbRed: 0.93, green: 0.33, blue: 0.49, alpha: 1))
                case "W": ctx.setFillColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.9, alpha: 1))
                default: continue
                }
                ctx.fill(CGRect(x: x, y: h - 1 - r, width: 1, height: 1))
            }
        }
        heartImage = ctx.makeImage()
        return heartImage
    }

    func heart(at p: CGPoint) {
        let l = CALayer()
        l.contents = heartGlyph()
        l.magnificationFilter = .nearest
        l.bounds = CGRect(x: 0, y: 0, width: 7 * px, height: 7 * px)
        l.position = p
        over.addSublayer(l)
        let m = CABasicAnimation(keyPath: "position.y")
        m.fromValue = p.y; m.toValue = p.y + 18 * px
        let f = CAKeyframeAnimation(keyPath: "opacity")
        f.values = [0, 1, 1, 0]; f.keyTimes = [0, 0.15, 0.6, 1]
        let g = CAAnimationGroup()
        g.animations = [m, f]; g.duration = 1.2
        g.isRemovedOnCompletion = false; g.fillMode = .forwards
        l.add(g, forKey: "h")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { l.removeFromSuperlayer() }
    }

    // MARK: veverka

    /// Veverka se přiřítí z kraje a sedne si; sprity koukají doleva.
    func showSquirrel(at p: CGPoint, size: CGFloat, fromRight: Bool) {
        hideSquirrel()
        let l = spriteLayer("veverka_sedi", flip: !fromRight)
        let sit = CGPoint(x: (p.x / px).rounded() * px, y: p.y + l.bounds.height / 2)
        l.position = sit
        over.addSublayer(l)
        squirrel = l
        squirrelPos = sit
        let run = [DogRenderer.frames["veverka_bezi0"], DogRenderer.frames["veverka_bezi1"]].compactMap { $0 }
        let legs = CAKeyframeAnimation(keyPath: "contents")
        legs.values = run + run + run
        legs.duration = 0.45
        legs.calculationMode = .discrete
        let m = CABasicAnimation(keyPath: "position.x")
        m.fromValue = sit.x + (fromRight ? 1 : -1) * 160; m.toValue = sit.x; m.duration = 0.45
        l.add(legs, forKey: "legs")
        l.add(m, forKey: "in")
    }

    func squirrelFlees(toRight: Bool) {
        guard let l = squirrel else { return }
        // otočí se a utíká pryč
        l.setAffineTransform(CGAffineTransform(scaleX: toRight ? -1 : 1, y: 1))
        let run = [DogRenderer.frames["veverka_bezi0"], DogRenderer.frames["veverka_bezi1"]].compactMap { $0 }
        let legs = CAKeyframeAnimation(keyPath: "contents")
        legs.values = run
        legs.duration = 0.16
        legs.repeatCount = 10
        legs.calculationMode = .discrete
        let to = CGPoint(x: l.position.x + (toRight ? 1 : -1) * 700, y: l.position.y)
        let m = CABasicAnimation(keyPath: "position")
        m.fromValue = NSValue(point: l.position); m.toValue = NSValue(point: to); m.duration = 0.8
        m.isRemovedOnCompletion = false; m.fillMode = .forwards
        l.add(legs, forKey: "legs")
        l.add(m, forKey: "flee")
        squirrel = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { l.removeFromSuperlayer() }
    }

    func hideSquirrel() {
        squirrel?.removeFromSuperlayer()
        squirrel = nil
    }

    var hasSquirrel: Bool { squirrel != nil }

    // MARK: tick

    func update(_ dt: CGFloat, floorY: CGFloat) {
        for p in particles {
            p.life -= dt
            p.vel.y -= p.gravity * dt
            p.layer.position.x += p.vel.x * dt
            p.layer.position.y += p.vel.y * dt
            p.layer.opacity = Float(max(0, min(1, p.life / (p.maxLife * 0.6))))
        }
        particles.removeAll { p in
            if p.life <= 0 { p.layer.removeFromSuperlayer(); return true }
            return false
        }
        // pamlsky padají a zůstanou ležet na Docku, dokud je Julie nesní
        for s in sausages {
            s.age += dt
            if let r = treatRange { s.pos.x = min(r.upperBound, max(r.lowerBound, s.pos.x)) }
            if !s.landed {
                s.vel.y -= 1100 * dt
                s.pos.x += s.vel.x * dt
                s.pos.y += s.vel.y * dt
                let rest = floorY + s.layer.bounds.height / 2 - px
                if s.pos.y <= rest { s.pos.y = rest; s.vel = .zero; s.landed = true }
            }
            s.layer.position = CGPoint(x: (s.pos.x / px).rounded() * px, y: (s.pos.y / px).rounded() * px)
            if s.age > 30 { s.layer.removeFromSuperlayer() }
        }
        sausages.removeAll { $0.age > 30 }
    }

    /// Děje se v efektech něco, co potřebuje plynulý pohyb? (letící hroudy, padající pamlsky)
    var isBusy: Bool { !particles.isEmpty || sausages.contains { !$0.landed } }

    /// Po přepnutí monitoru s jinou hustotou pixelů.
    func setScale(_ sc: CGFloat) {
        dogLayer.contentsScale = sc
        bubble.contentsScale = sc
    }

    func clearSausages() {
        for s in sausages { s.layer.removeFromSuperlayer() }
        sausages.removeAll()
    }
}
