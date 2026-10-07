import Cocoa

/// Měření simulovaného dne: `Julie --mereni [od hodiny] [počet hodin]` (výchozí 8:00, 8 hodin).
/// Julie běží sama, bez člověka (kurzor stojí nad Dockem, nikdo nekliká), s falešnými hodinami.
/// Vypíše, jak často co dělá, jak hned za sebou štěká a leze do nory a kolikrát se činnost opakuje.
/// Chování nijak nemění; podle výsledku se rozhoduje, jestli jsou potřeba pauzy mezi opakováním (rada 7. 10. 2026).
func zmerDen(od: Double, hodin: Double) {
    _ = NSApplication.shared
    DogRenderer.load()
    let env = Env()
    let fx = Effects(scale: 2)
    fx.px = 2
    fx.treatRange = (env.dockL + 20)...(env.dockR - 20)
    var cfg = Config()                  // výchozí nastavení nového uživatele (darebáctví zapnuté)
    cfg.size = 80; cfg.windowPlatforms = false
    let pet = Pet(cfg: cfg, env: env, fx: fx)
    pet.pixel = 2
    pet.mode = .ground
    pet.surfaceId = 0
    pet.pos = CGPoint(x: (env.dockL + env.dockR) / 2, y: env.floorY + DogRenderer.ground * pet.s)
    pet.bedSpot = CGPoint(x: env.dockR + 70, y: env.screen.frame.minY + 14)
    pet.setAct(.sit, 2)

    var t: Double = 0
    var zacatky: [(Double, Act)] = []
    var doba: [String: Double] = [:]
    var balonky = 0
    var minulyMode = pet.mode
    pet.pozorovatel = { a in zacatky.append((t, a)) }
    let mys = Input(mouse: CGPoint(x: (env.dockL + env.dockR) / 2, y: env.floorY + 300), typing: false)
    let dt: CGFloat = 0.1
    let konec = hodin * 3600
    var krok = 0
    while t < konec {
        pet.simHodina = od + t / 3600
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        Pet.step(pet, fx, dt, mys, floorY: env.floorY)
        CATransaction.commit()
        doba["\(pet.act)", default: 0] += Double(dt)
        if pet.mode == .balloon && minulyMode != .balloon { balonky += 1 }
        minulyMode = pet.mode
        t += Double(dt)
        krok += 1
        if krok % 3000 == 0 { RunLoop.main.run(until: Date()) }   // odložené úklidy efektů
    }

    // souhrn
    func cas(_ h: Double) -> String { String(format: "%02d:%02d", Int(h) % 24, Int((h - floor(h)) * 60)) }
    print("Simulovaný den \(cas(od))–\(cas(od + hodin)), Julie sama, bez člověka (\(String(format: "%.0f", hodin)) h)\n")
    var pocty: [String: Int] = [:]
    for (_, a) in zacatky { pocty["\(a)", default: 0] += 1 }
    // nejdelší řada stejné činnosti po sobě
    var rada: [String: Int] = [:]
    var hned: [String: Int] = [:]
    var predchozi = "", delka = 0
    for (_, a) in zacatky {
        let n = "\(a)"
        if n == predchozi { delka += 1; hned[n, default: 0] += 1 } else { delka = 1; predchozi = n }
        rada[n] = max(rada[n] ?? 0, delka)
    }
    func sloupec(_ text: String, _ sirka: Int, vlevo: Bool = false) -> String {
        let mezery = String(repeating: " ", count: max(0, sirka - text.count))
        return vlevo ? text + mezery : mezery + text
    }
    print(sloupec("činnost", 10, vlevo: true) + sloupec("počet", 7) + sloupec("za hodinu", 11) + sloupec("podíl času", 12)
          + sloupec("hned po sobě", 14) + sloupec("nejdelší řada", 15))
    for (n, c) in pocty.sorted(by: { $0.value > $1.value }) {
        let podil = (doba[n] ?? 0) / konec * 100
        print(sloupec(n, 10, vlevo: true) + sloupec("\(c)", 7) + sloupec(String(format: "%.1f", Double(c) / hodin), 11)
              + sloupec(String(format: "%.1f %%", podil), 12) + sloupec("\(hned[n] ?? 0)", 14) + sloupec("\(rada[n] ?? 0)", 15))
    }
    func odstupy(_ jmeno: String, _ hranice: Double) {
        let casy = zacatky.filter { "\($0.1)" == jmeno }.map { $0.0 }
        guard casy.count >= 2 else { print("\n\(jmeno): \(casy.count)× – odstupy nejdou spočítat"); return }
        let d = zip(casy.dropFirst(), casy).map { $0 - $1 }.sorted()
        let kratke = d.filter { $0 < hranice }.count
        print(String(format: "\n%@: %d×, odstup nejkratší %.0f s, medián %.0f s, kratší než %.0f s: %d×",
                     jmeno as NSString, casy.count, d.first!, d[d.count / 2], hranice, kratke))
    }
    odstupy("bark", 45)
    odstupy("dig", 120)
    print(String(format: "\npřekvapení: veverka %d×, déšť pamlsků %d×, balónky %d×",
                 pocty["squirrel"] ?? 0, pocty["sausage"] ?? 0, balonky))
    let odpocinek = ["sleep", "lie", "inBed", "sit"].reduce(0) { $0 + (doba[$1] ?? 0) } / konec * 100
    print(String(format: "odpočinek (spí, leží, v pelíšku, sedí): %.0f %% času", odpocinek))
}
