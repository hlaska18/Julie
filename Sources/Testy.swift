import Cocoa

/// Samotest bez obrazovky: `Julie --test`. Hlídá chování, které se už jednou rozbilo.
/// Vrací true, když všechno prošlo.
func runSelfTest() -> Bool {
    _ = NSApplication.shared
    DogRenderer.load()
    var ok = true
    func vysledek(_ jmeno: String, _ prosel: Bool, _ detail: String = "") {
        print((prosel ? "OK     " : "CHYBA  ") + jmeno + (detail.isEmpty ? "" : " – " + detail))
        if !prosel { ok = false }
    }
    func novy() -> (Pet, Effects, Env) {
        let env = Env()
        let fx = Effects(scale: 2)
        fx.px = 2
        var cfg = Config()
        cfg.size = 80; cfg.mischief = false; cfg.windowPlatforms = false; cfg.eyeTracking = false
        let pet = Pet(cfg: cfg, env: env, fx: fx)
        pet.pixel = 2
        return (pet, fx, env)
    }
    let nikde = Input(mouse: CGPoint(x: -9999, y: -9999), typing: false)
    func naZemi(_ pet: Pet, _ env: Env, x: CGFloat? = nil) {
        pet.mode = .ground
        pet.surfaceId = 0
        pet.pos = CGPoint(x: x ?? (env.dockL + env.dockR) / 2, y: env.floorY + DogRenderer.ground * pet.s)
        pet.setAct(.sit, 60)
    }

    // 1) dopad bez odrazu (a s hrubým krokem 1/8 s – simulace po kouscích)
    do {
        let (pet, fx, env) = novy()
        pet.pos = CGPoint(x: (env.dockL + env.dockR) / 2, y: env.floorY + 600)
        pet.startAir(v: CGPoint(x: 150, y: 0))
        var pristala = false, odrazila = false, otrepala = false
        for _ in 0..<64 {
            Pet.step(pet, fx, 1.0 / 8, nikde, floorY: env.floorY)
            if pet.mode == .ground { pristala = true }
            if pristala && pet.mode == .air { odrazila = true }
            if pet.act == .shake || pet.act == .dizzy { otrepala = true }
        }
        vysledek("pád: dopadne bez odrazu a otřepe se", pristala && !odrazila && otrepala)
    }

    // 2) padáček z výšky
    do {
        let (pet, fx, env) = novy()
        pet.mode = .grab
        pet.pos = CGPoint(x: (env.dockL + env.dockR) / 2, y: env.screen.frame.maxY - 150)
        pet.release()
        let mel = pet.mode == .parachute
        var t: CGFloat = 0
        while t < 40 && pet.mode == .parachute { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY); t += 1.0 / 30 }
        vysledek("padáček: otevře se a přistane", mel && pet.mode == .ground, String(format: "%.1f s", t))
    }

    // 3) déšť pamlsků: po celém Docku, dopadnou na Dock, nemizí ve vzduchu, Julie sní všechny
    for rychlost in [1.0, 0.3] {
        let (pet, fx, env) = novy()
        pet.cfg.walkSpeed = rychlost
        fx.treatRange = (env.dockL + 20)...(env.dockR - 20)
        naZemi(pet, env)
        pet.rainTreats()
        var naposled: [ObjectIdentifier: Bool] = [:]
        var drzene: [Sausage] = []       // podržet: snědený pamlsek by jinak uvolnil adresu a nový by dostal stejné ObjectIdentifier
        var dopadly: [ObjectIdentifier: CGFloat] = [:]
        var zmizelVeVzduchu = false
        var mimo = false
        var snedla = 0
        var t: CGFloat = 0
        while t < 70 {
            Pet.step(pet, fx, 1.0 / 60, nikde, floorY: env.floorY); t += 1.0 / 60
            let ted = Set(fx.sausages.map { ObjectIdentifier($0) })
            for (id, lezel) in naposled where !ted.contains(id) {
                if lezel { snedla += 1 } else { zmizelVeVzduchu = true }
            }
            naposled = [:]
            for sa in fx.sausages {
                if !drzene.contains(where: { $0 === sa }) { drzene.append(sa) }
                naposled[ObjectIdentifier(sa)] = sa.landed
                if sa.landed && dopadly[ObjectIdentifier(sa)] == nil { dopadly[ObjectIdentifier(sa)] = sa.pos.x }
                if sa.pos.x < env.dockL + 19 || sa.pos.x > env.dockR - 19 { mimo = true }
            }
            if pet.act != .sausage && fx.sausages.isEmpty { break }
        }
        let xs = dopadly.values
        let rozptyl = ((xs.max() ?? 0) - (xs.min() ?? 0)) / (env.dockR - env.dockL)
        vysledek("déšť pamlsků po celém Docku (rychlost \(rychlost))",
                 !zmizelVeVzduchu && !mimo && snedla == 6 && pet.act != .sit && rozptyl > 0.6,
                 String(format: "snědla %d z 6 za %.0f s, rozptyl %.0f %% Docku", snedla, t, rozptyl * 100))
    }

    // 3b) pamlsek zmizí až potom, co Julie skloní hlavu (ne dřív)
    do {
        let (pet, fx, env) = novy()
        fx.treatRange = (env.dockL + 20)...(env.dockR - 20)
        naZemi(pet, env)
        pet.dropTreat(at: pet.pos.x + 200, fromY: env.floorY + 300)
        pet.setAct(.sausage, 999)
        var dole: CGFloat = 0          // jak dlouho má hlavu dole
        var dobaPredSnezenim: CGFloat = -1
        var t: CGFloat = 0
        while t < 15 && dobaPredSnezenim < 0 {
            let bylo = fx.sausages.count
            Pet.step(pet, fx, 1.0 / 60, nikde, floorY: env.floorY); t += 1.0 / 60
            if fx.sausages.count < bylo { dobaPredSnezenim = dole }
            dole = pet.buildPose().frame == "cuch" ? dole + 1.0 / 60 : 0
        }
        vysledek("pamlsek: zmizí až po sklopení hlavy", dobaPredSnezenim >= 0.3, String(format: "hlava dole %.2f s předtím", dobaPredSnezenim))
    }

    // 3c) dosáhne i na pamlsky na krajích Docku a nepřečnívá přes ně (velikosti z nabídky)
    for velikost in [56.0, 80.0, 110.0, 150.0] {
        var snedla = 0
        var precniva: CGFloat = 0
        for kraj in [-1.0, 1.0] as [CGFloat] {
            let (pet, fx, env) = novy()
            pet.cfg.size = velikost
            pet.pixel = max(2, (CGFloat(velikost) / 38).rounded()); fx.px = pet.pixel
            fx.treatRange = (env.dockL + 20)...(env.dockR - 20)
            let okraj = kraj < 0 ? env.dockL : env.dockR
            naZemi(pet, env, x: okraj - kraj * 300)
            pet.dropTreat(at: okraj, fromY: env.floorY + 200)
            pet.setAct(.sausage, 999)
            var t: CGFloat = 0
            while t < 20 && !fx.sausages.isEmpty {
                Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY); t += 1.0 / 30
                let pul = pet.half * pet.pixel
                precniva = max(precniva, env.dockL - (pet.pos.x - pul), (pet.pos.x + pul) - env.dockR)
            }
            if fx.sausages.isEmpty && pet.act != .sit { snedla += 1 }    // .sit = po 25 s by je uklidila
            // pak dojde až na kraj Docku: čumák ani ocas nesmí přečnívat
            pet.setAct(.walk, 30); pet.walkDir = kraj
            for _ in 0..<(30 * 6) {
                Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY)
                let pul = pet.half * pet.pixel
                precniva = max(precniva, env.dockL - (pet.pos.x - pul), (pet.pos.x + pul) - env.dockR)
            }
        }
        vysledek("pamlsky na krajích Docku (velikost \(Int(velikost)))", snedla == 2 && precniva <= 0.5,
                 String(format: "snědla %d ze 2, přečnívá %.1f b.", snedla, precniva))
    }

    // 4) míček: přinese ho pod kurzor
    do {
        let (pet, fx, env) = novy()
        naZemi(pet, env)
        let mid = (env.dockL + env.dockR) / 2
        let mys = Input(mouse: CGPoint(x: mid - 150, y: env.floorY + 200), typing: false)
        pet.throwBall(from: CGPoint(x: mid + 250, y: env.floorY + 400), vel: CGPoint(x: -150, y: 250))
        var t: CGFloat = 0
        while t < 25 && !(pet.act == .fetchBall && pet.ballPhase == 2) { Pet.step(pet, fx, 1.0 / 30, mys, floorY: env.floorY); t += 1.0 / 30 }
        vysledek("míček: přinese ho pod kurzor", pet.ballPhase == 2 && abs(pet.pos.x - (mid - 150)) < 40, String(format: "%.1f s", t))
    }

    // 5) pelíšek: dojde, lehne si, po druhém kliknutí vstane
    do {
        let (pet, fx, env) = novy()
        naZemi(pet, env)
        pet.bedSpot = CGPoint(x: env.dockR + 70, y: env.screen.frame.minY + 14)
        pet.bedToggle()
        var t: CGFloat = 0
        while t < 30 && pet.act != .inBed { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY); t += 1.0 / 30 }
        let lehla = pet.act == .inBed
        pet.bedToggle()
        var vstala = false
        for _ in 0..<90 { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY); if [.stretch, .walk, .sit].contains(pet.act) { vstala = true; break } }
        vysledek("pelíšek: lehne si a po kliknutí vstane", lehla && vstala, String(format: "%.1f s", t))
    }

    // 6) nora: vyleze přímo z díry (díra je za ocasem), i když se otočí
    do {
        let (pet, fx, env) = novy()
        naZemi(pet, env)
        pet.facing = 1
        pet.forceFacing = -1
        pet.setAct(.dig, 1)
        var t: CGFloat = 0
        var seda = true
        while t < 15 && pet.act == .dig {
            Pet.step(pet, fx, 1.0 / 60, nikde, floorY: env.floorY); t += 1.0 / 60
            if pet.burrowPhase == 7 {
                let ocas = pet.pos.x - pet.facing * pet.half * pet.pixel
                seda = abs(pet.lastHoleX - ocas) <= 4 * pet.pixel
                break
            }
        }
        vysledek("nora: vyleze z díry (díra je u ocasu)", seda)
    }

    // 7) reakce na Claude Code „hrabe“ se hned nezruší
    do {
        let (pet, fx, env) = novy()
        naZemi(pet, env)
        pet.reactToClaude("bash")
        for _ in 0..<30 { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY) }
        vysledek("Claude: hrabání vydrží", pet.act == .scrabble)
    }

    // 8) nesený míček nezmizí, když Julie přejde na jinou činnost
    do {
        let (pet, _, env) = novy()
        naZemi(pet, env)
        pet.ball = Pet.Ball(pos: pet.pos, vel: .zero, onGround: true, carried: true)
        pet.setAct(.happy, 1)
        vysledek("míček: při jiné činnosti ho položí", pet.ball?.carried == false)
    }

    // 9) rychlost nezávisí na počtu snímků
    do {
        func ujde(_ krok: CGFloat) -> CGFloat {
            let (pet, fx, env) = novy()
            naZemi(pet, env, x: env.dockL + 200)
            pet.setAct(.walk, 30)
            pet.walkDir = 1
            let x0 = pet.pos.x
            var t: CGFloat = 0
            while t < 3 { Pet.step(pet, fx, krok, nikde, floorY: env.floorY); t += krok }
            return pet.pos.x - x0
        }
        let a = ujde(1.0 / 60), b = ujde(1.0 / 6)
        vysledek("rychlost chůze stejná při 60 i 6 snímcích/s", a > 10 && abs(a - b) / a < 0.1, String(format: "%.0f vs %.0f bodů", a, b))
    }

    // 9b) přivolání na padáčku: padáček se nepřeruší, po dopadu přijde
    do {
        let (pet, fx, env) = novy()
        pet.mode = .grab
        pet.pos = CGPoint(x: (env.dockL + env.dockR) / 2, y: env.screen.frame.maxY - 150)
        pet.release()
        let mys = Input(mouse: CGPoint(x: env.dockL + 100, y: env.floorY + 100), typing: false)
        pet.call(to: mys.mouse)
        var naPadaku = pet.mode == .parachute, prisla = false
        var t: CGFloat = 0
        while t < 40 {
            Pet.step(pet, fx, 1.0 / 30, mys, floorY: env.floorY); t += 1.0 / 30
            if pet.mode == .air { naPadaku = false }
            if pet.act == .follow && pet.mode == .ground { prisla = true; break }
        }
        vysledek("přivolání na padáčku: doletí na padáčku, pak přijde", naPadaku && prisla, String(format: "%.1f s", t))
    }

    // 9c) přivolání nemaže pamlsky na Docku a pamlsek má přednost
    do {
        let (pet, fx, env) = novy()
        fx.treatRange = (env.dockL + 20)...(env.dockR - 20)
        naZemi(pet, env)
        pet.dropTreat(at: pet.pos.x + 300, fromY: env.floorY + 10)
        for _ in 0..<30 { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY) }
        pet.setAct(.sit, 60)
        pet.call(to: CGPoint(x: env.dockL + 50, y: env.floorY + 50))
        let zustal = fx.sausages.count == 1
        // pak ho sní (po přivolání si ho všimne)
        var t: CGFloat = 0
        while t < 40 && !fx.sausages.isEmpty { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY); t += 1.0 / 30 }
        vysledek("přivolání: pamlsky na Docku nezmizí, Julie je pak sní", zustal && fx.sausages.isEmpty, String(format: "%.1f s", t))
    }

    // 9d) ležící pamlsek má v nextAct přednost před pelíškem, ležením i míčkem
    do {
        let (pet, fx, env) = novy()
        fx.treatRange = (env.dockL + 20)...(env.dockR - 20)
        naZemi(pet, env)
        pet.bedSpot = CGPoint(x: env.dockR + 70, y: env.screen.frame.minY + 14)
        pet.ball = Pet.Ball(pos: CGPoint(x: pet.pos.x + 200, y: env.floorY + 10), vel: .zero, onGround: true, carried: false)
        pet.dropTreat(at: pet.pos.x - 300, fromY: env.floorY + 10)
        var vzdy = true
        for _ in 0..<200 {
            pet.setAct(.sit, 1)
            pet.nextAct(nikde)
            if pet.act != .sausage { vzdy = false; break }
        }
        vysledek("ležící pamlsek má přednost před pelíškem, ležením i míčkem", vzdy)
    }

    // 9e) přivolání pod zemí: nora se dokončí (vyleze z díry), pak přijde
    do {
        let (pet, fx, env) = novy()
        naZemi(pet, env)
        pet.setAct(.dig, 1)
        var t: CGFloat = 0
        while t < 15 && pet.burrowPhase < 3 { Pet.step(pet, fx, 1.0 / 60, nikde, floorY: env.floorY); t += 1.0 / 60 }
        let mys = CGPoint(x: env.dockL + 60, y: env.floorY + 60)
        pet.call(to: mys)
        let dohrabala = pet.act == .dig
        var vylezla = false, prisla = false
        while t < 30 {
            Pet.step(pet, fx, 1.0 / 60, Input(mouse: mys, typing: false), floorY: env.floorY); t += 1.0 / 60
            if pet.act == .dig && pet.burrowPhase >= 6 { vylezla = true }
            if pet.act == .follow { prisla = true; break }
        }
        vysledek("přivolání pod zemí: nejdřív vyleze z díry, pak přijde", dohrabala && vylezla && prisla)
    }

    // 9f) přivolání z pelíšku: vyskočí ven (ne přesun skrz okraj), pak přijde
    do {
        let (pet, fx, env) = novy()
        naZemi(pet, env)
        pet.bedSpot = CGPoint(x: env.dockR + 70, y: env.screen.frame.minY + 14)
        pet.bedToggle()
        var t: CGFloat = 0
        while t < 30 && pet.act != .inBed { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY); t += 1.0 / 30 }
        let mys = CGPoint(x: env.dockL + 60, y: env.floorY + 60)
        pet.call(to: mys)
        var vyskocila = false, prisla = false
        for _ in 0..<(30 * 8) {
            Pet.step(pet, fx, 1.0 / 30, Input(mouse: mys, typing: false), floorY: env.floorY)
            if pet.act == .outOfBed { vyskocila = true }
            if pet.act == .follow { prisla = true; break }
        }
        vysledek("přivolání z pelíšku: vyskočí ven, pak přijde", vyskocila && prisla)
    }

    // 9g) překvapení se odpočítávají podle času, kdy je vzhůru (ne podle délky činnosti)
    do {
        let (pet, fx, env) = novy()
        pet.cfg.mischief = true
        naZemi(pet, env)
        pet.setAct(.sit, 999)
        pet.nextEgg = 500
        for _ in 0..<(30 * 10) { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY) }
        let vzhuru = 500 - pet.nextEgg
        pet.setAct(.sleep, 999)
        let pred = pet.nextEgg
        for _ in 0..<(30 * 10) { Pet.step(pet, fx, 1.0 / 30, nikde, floorY: env.floorY) }
        vysledek("překvapení: odpočet běží jen vzhůru a podle času", abs(vzhuru - 10) < 0.5 && pet.nextEgg == pred,
                 String(format: "vzhůru %.1f s, ve spánku %.1f s", vzhuru, pred - pet.nextEgg))
    }

    // 10) všechny jazyky mají všechny texty
    do {
        let klice = Set(Texty.tabulka["cs"]!.keys)
        var chybi: [String] = []
        for (kod, t) in Texty.tabulka where Set(t.keys) != klice {
            chybi.append(kod + ": " + klice.symmetricDifference(Set(t.keys)).sorted().joined(separator: ","))
        }
        vysledek("texty: všech \(Texty.tabulka.count) jazyků má všechny texty", chybi.isEmpty, chybi.joined(separator: "; "))
    }

    return ok
}
