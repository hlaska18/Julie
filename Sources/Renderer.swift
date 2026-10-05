import Cocoa

/// Co se má nakreslit: jeden snímek Julie (pixel art z Higgsfieldu) a jeho natočení.
struct DogPose: Equatable {
    var frame = "stoji"
    var rot: CGFloat = 0
    var squash: CGFloat = 0          // zploštění při dopadu
    var stretch: CGFloat = 1         // natažení ve vzduchu
    var hang = false                 // visí: kotva je u krku nahoře, ne u tlapek
    var balloons = 0
    var balloonSway: CGFloat = 0
    var offset = CGPoint.zero        // posun snímku v pixelech obrázku (nora)
    var clipGround = false           // co je pod zemí, není vidět
    var hidden = false               // pod zemí celá
    var chute: CGFloat = 0           // padáček 0…1 (rozevřený)
    var chuteLanded = false          // přistála: padáček splaskává za ní
}

extension DogPose {
    /// Zaokrouhlené hodnoty: drobné rozdíly nemají vyvolat nové kreslení stejného obrázku.
    func quantized() -> DogPose {
        var p = self
        p.rot = (p.rot * 50).rounded() / 50
        p.squash = (p.squash * 50).rounded() / 50
        p.stretch = (p.stretch * 50).rounded() / 50
        p.balloonSway = (p.balloonSway * 20).rounded() / 20
        p.chute = (p.chute * 20).rounded() / 20
        p.offset = CGPoint(x: p.offset.x.rounded(), y: p.offset.y.rounded())
        return p
    }
}

private func col(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: a)
}

enum DogRenderer {
    /// Vzdálenost země pod středem těla (v jednotkách velikosti, 100 = šířka psa).
    static let ground: CGFloat = 24
    /// Kolik pixelů obrázku je krk pod horním okrajem snímku „visi“.
    static var neckFromTop: CGFloat { (CGFloat(frames["visi"]?.height ?? 54) * 0.2).rounded() }
    static var standHeight: CGFloat { CGFloat(frames["stoji"]?.height ?? 29) }

    private(set) static var frames: [String: CGImage] = [:]
    static var standWidth: CGFloat { CGFloat(frames["stoji"]?.width ?? 54) }

    static func load() {
        var dirs: [URL] = []
        if let r = Bundle.main.resourceURL { dirs.append(r.appendingPathComponent("sprity")) }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        dirs.append(exe.deletingLastPathComponent().appendingPathComponent("../../../art/sprity").standardized)
        for d in dirs {
            guard let files = try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil) else { continue }
            for f in files where f.pathExtension == "png" {
                if let src = CGImageSourceCreateWithURL(f as CFURL, nil),
                   let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                    frames[f.deletingPathExtension().lastPathComponent] = img
                }
            }
            if !frames.isEmpty { return }
        }
    }

    /// Vykreslí snímek do malé bitmapy (1 pixel obrázku = 1 pixel bitmapy), bez vyhlazování.
    /// Vrstva ji pak zvětší `px`-krát metodou nejbližšího souseda.
    static func sprite(pose p: DogPose, scale s: CGFloat, facing f: CGFloat, side: CGFloat, px: CGFloat) -> CGImage? {
        let n = max(8, Int((side / px).rounded()))
        guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setShouldAntialias(false)
        ctx.setAllowsAntialiasing(false)
        ctx.interpolationQuality = .none
        let c = CGFloat(n / 2)
        let g = ground * s / px

        if p.balloons > 0 {
            ctx.saveGState()
            ctx.translateBy(x: c, y: c)
            ctx.scaleBy(x: s / px, y: s / px)
            drawBalloons(ctx, p, anchor: p.hang ? CGPoint(x: 0, y: -2) : CGPoint(x: -4, y: 8))
            ctx.restoreGState()
        }

        if p.chute > 0 { drawParachute(ctx, c: c, p: p, g: g) }
        guard !p.hidden, let img = frames[p.frame] ?? frames["stoji"] else { return ctx.makeImage() }
        let w = CGFloat(img.width), h = CGFloat(img.height)
        if p.clipGround {
            ctx.clip(to: CGRect(x: 0, y: c - g.rounded(), width: CGFloat(n), height: CGFloat(n)))
        }
        ctx.translateBy(x: c + p.offset.x.rounded(), y: c + p.offset.y.rounded())
        ctx.scaleBy(x: f, y: 1)
        ctx.rotate(by: p.rot)
        let ox: CGFloat, oy: CGFloat
        if p.hang {
            ox = -(w / 2).rounded()
            oy = -h + neckFromTop
        } else {
            // snímky na zemi jsou zarovnané podle hlavy, ať při střídání neposkakuje
            ox = (standWidth / 2).rounded() - w
            oy = -g.rounded()
        }
        let hs = (1 + p.squash * 0.3) * p.stretch
        let vs = 1 - p.squash * 0.45
        if hs != 1 || vs != 1 {
            ctx.translateBy(x: 0, y: oy)
            ctx.scaleBy(x: hs, y: vs)
            ctx.translateBy(x: 0, y: -oy)
        }
        ctx.draw(img, in: CGRect(x: ox, y: oy, width: w, height: h))
        return ctx.makeImage()
    }

    /// Pixelový padáček (tyrkysové a krémové pruhy), v pixelech obrázku, bez vyhlazování.
    static func drawParachute(_ c: CGContext, c center: CGFloat, p: DogPose, g: CGFloat) {
        c.saveGState()
        let o = p.chute
        let w = (34 * (0.35 + 0.65 * o)).rounded()
        let hgt = (12 * o).rounded()
        // kotva: krk (visí) nebo hřbet (stojí po přistání, padáček leží za ní)
        let anchor = p.chuteLanded ? CGPoint(x: center - 6, y: center - g + 10) : CGPoint(x: center, y: center)
        let top = p.chuteLanded ? anchor.y + 6 + hgt : anchor.y + 22
        let rimY = top - hgt
        let left = anchor.x - w / 2
        // šňůry
        c.setStrokeColor(col(0x4A3A30))
        c.setLineWidth(1)
        if !p.chuteLanded || o > 0.3 {
            for k in 0...3 {
                let rx = left + CGFloat(k) / 3 * w
                c.move(to: CGPoint(x: rx, y: rimY))
                c.addLine(to: anchor)
            }
            c.strokePath()
        }
        // vrchlík: půlelipsa složená z pruhů
        if hgt >= 1 {
            let stripes = 6
            for i in 0..<stripes {
                let x0 = left + CGFloat(i) / CGFloat(stripes) * w
                let x1 = left + CGFloat(i + 1) / CGFloat(stripes) * w
                c.saveGState()
                c.clip(to: CGRect(x: x0, y: rimY, width: x1 - x0, height: hgt + 1))
                c.setFillColor(i % 2 == 0 ? col(0x0C8A83) : col(0xF3EBDD))
                c.fillEllipse(in: CGRect(x: left, y: rimY - hgt, width: w, height: hgt * 2))
                c.restoreGState()
            }
            // spodní lem
            c.setFillColor(col(0x076B66))
            c.fill(CGRect(x: left, y: rimY, width: w, height: 1))
        }
        c.restoreGState()
    }

    static func drawBalloons(_ c: CGContext, _ p: DogPose, anchor: CGPoint) {
        let colors: [UInt32] = [0xE8505B, 0xF2C14E, 0x4FA3E0]
        let xs: [CGFloat] = [-16, 0, 16]
        let hs: [CGFloat] = [62, 74, 58]
        for i in 0..<min(3, p.balloons) {
            let sway = p.balloonSway * (1 + CGFloat(i) * 0.3)
            let top = CGPoint(x: anchor.x + xs[i] + sway * hs[i] * 0.2, y: anchor.y + hs[i])
            c.setStrokeColor(col(0x555555))
            c.setLineWidth(1.2)
            c.move(to: anchor)
            c.addQuadCurve(to: CGPoint(x: top.x, y: top.y - 14), control: CGPoint(x: anchor.x + xs[i] * 0.2, y: anchor.y + hs[i] * 0.5))
            c.strokePath()
            let r = CGRect(x: top.x - 11, y: top.y - 14, width: 22, height: 28)
            c.setFillColor(col(colors[i]))
            c.fillEllipse(in: r)
            c.setStrokeColor(col(0x3A1A0C))
            c.setLineWidth(2.4)
            c.strokeEllipse(in: r)
            c.setFillColor(col(0xFFFFFF, 0.7))
            c.fillEllipse(in: CGRect(x: top.x - 6, y: top.y + 3, width: 5, height: 8))
        }
    }
}
