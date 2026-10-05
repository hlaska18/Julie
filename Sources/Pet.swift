import Cocoa

enum Mode { case ground, toClimb, climb, mantle, grab, air, balloon, parachute }

enum Act {
    case walk, follow, sit, lie, sleep, sniff, scratch, stretch, bark, look, dig, scrabble, happy, dizzy
    case meteor, squirrel, sausage, shake, petted, toBed, inBed, outOfBed, fetch, fetchBall
}

struct Input {
    var mouse: CGPoint
    var typing: Bool
}

final class Pet {
    var cfg: Config
    let env: Env
    let fx: Effects

    var s: CGFloat { CGFloat(cfg.size) / 100 }
    var pos = CGPoint(x: 600, y: 700)
    var vel = CGPoint.zero
    var facing: CGFloat = 1
    var mode: Mode = .air
    var act: Act = .sit
    var actT: CGFloat = 0
    var actDur: CGFloat = 2
    var walkDir: CGFloat = 1
    var phase: CGFloat = 0
    var speedNow: CGFloat = 0
    var surfaceId = 0
    var relX: CGFloat = 0
    var rot: CGFloat = 0
    var rotTarget: CGFloat = 0
    var q: CGFloat = 0, qv: CGFloat = 0
    var clock: CGFloat = 0
    var blinkIn: CGFloat = 2.5, blinkT: CGFloat = 0
    var look = CGPoint.zero
    var typeReact: CGFloat = 0
    var typingBefore = false
    var yOff: CGFloat = 0
    var watchAct: Act?
    var watchText: String?
    var speech: String?
    var speechT: CGFloat = 0
    var impact: CGFloat = 0
    var bounces = 0
    var zzzT: CGFloat = 0
    var pawT: CGFloat = 0
    var sinkAmt: CGFloat = 0
    var holeX: CGFloat = 0
    var didTeleport = false
    var burrowPhase = 0
    var burrowT: CGFloat = 0
    var burrowRot: CGFloat = 0
    var burrowOff = CGPoint.zero
    var burrowFrame = "hrabe0"
    var burrowClip = false
    var burrowTarget: CGFloat = 0
    var trailX: CGFloat = 0
    var burrowJitter: CGFloat = 0       // třes při hrabání (pixely)
    var lastHoleX: CGFloat = 0          // kde je naposledy vyhrabaná díra (pro kontrolu)
    var forceFacing: CGFloat?           // jen pro zkoušku: směr po vynoření
    var treatsToDrop = 0
    var treatDropT: CGFloat = 0
    var eatT: CGFloat = 0
    var treatMoving = false
    var heartT: CGFloat = 0
    var bedUntilClick = false
    var toBedMoving = false
    var wantBed = false
    var bedJumpT: CGFloat = -1
    var bedPrepT: CGFloat = -1
    var heldTreatPos: CGPoint?      // pamlsek v ruce u kurzoru (nastavuje aplikace)
    var ball: Ball?                 // míček (nil = žádný)
    var ballPhase = 0
    var ballT: CGFloat = 0
    var ballMoving = false
    var ballHeldByUser = false      // míček drží myš
    var lastClaudeReact: CGFloat = -99
    var fetchPhase = 0
    var fetchT: CGFloat = 0
    var fetchMoving = false
    var begTries = 0
    var hover: CGFloat = 0
    var stretchExtra: CGFloat = 0
    var lastTurn: CGFloat = 0
    var pixel: CGFloat = 2

    // dangle
    var phi: CGFloat = 0, phiV: CGFloat = 0
    var cursorVX: CGFloat = 0
    var lastMouse = CGPoint.zero
    var history: [(CGFloat, CGPoint)] = []

    // climb
    var climbId = 0
    var climbF: CGFloat = 1
    var mantleT: CGFloat = 0
    var mantleFrom = CGPoint.zero
    var mantleTo = CGPoint.zero
    var toClimbT: CGFloat = 0

    // balloon
    var balloons = 0
    var balloonT: CGFloat = 0

    // eggs
    var eggT: CGFloat = 0
    var squirrelPhase = 0
    var squirrelX: CGFloat = 0
    var squirrelSide: CGFloat = 1
    var nextEgg: CGFloat = CGFloat.random(in: 70...150)

    init(cfg: Config, env: Env, fx: Effects) {
        self.cfg = cfg
        self.env = env
        self.fx = fx
        pos = CGPoint(x: (env.left + env.right) / 2, y: env.floorY + 300)
    }

    // MARK: pomocné

    /// Julie nemluví (Karel nechce bubliny); volání zůstávají jen jako popis chování.
    func say(_ t: String, _ dur: CGFloat = 2.2) {}

    var bubbleText: String? { nil }

    /// Pixelové zvukové vlny od tlamy = štěknutí.
    func barkFX() {
        fx.barkWaves(at: CGPoint(x: pos.x + facing * (half + 2) * pixel, y: pos.y - DogRenderer.ground * s + DogRenderer.standHeight * 0.8 * pixel), facing: facing, px: pixel)
    }

    var hitRect: CGRect {
        if act == .dig && burrowPhase >= 2 && burrowPhase <= 4 && mode == .ground { return .zero }
        switch mode {
        case .grab, .balloon,
             .parachute where chuteLanded < 0:
            let v = DogRenderer.frames["visi"]
            let vw = CGFloat(v?.width ?? 24), vh = CGFloat(v?.height ?? 52)
            return CGRect(x: pos.x - vw / 2 * pixel, y: pos.y - (vh - DogRenderer.neckFromTop) * pixel, width: vw * pixel, height: vh * pixel)
        case .climb, .mantle:
            return CGRect(x: pos.x - 18 * pixel, y: pos.y - 30 * pixel, width: 36 * pixel, height: 60 * pixel)
        default:
            return CGRect(x: pos.x - (half + 1) * pixel, y: pos.y - DogRenderer.ground * s, width: (2 * half + 2) * pixel, height: (DogRenderer.standHeight + 3) * pixel)
        }
    }

    func surfaceTop() -> CGFloat? {
        if surfaceId == 0 { return env.floorY }
        return env.window(surfaceId)?.top
    }

    func bounds() -> (CGFloat, CGFloat) {
        if surfaceId == 0 {
            let lo = env.dockL + 70 * s, hi = env.dockR - 70 * s
            return lo > hi ? ((lo + hi) / 2, (lo + hi) / 2) : (lo, hi)
        }
        if let w = env.window(surfaceId) { return (w.frame.minX + 22 * s, w.frame.maxX - 22 * s) }
        return (env.left, env.right)
    }

    func setAct(_ a: Act, _ dur: CGFloat) {
        if a != .fetchBall, ball?.carried == true { ball?.carried = false; ball?.vel = .zero }
        act = a
        actT = 0
        actDur = dur
        eggT = 0
        squirrelPhase = 0
        didTeleport = false
        if a != .toBed { bedJumpT = -1; bedPrepT = -1 }
        if a == .dig { holeX = pos.x; actDur = 999; burrowPhase = 0; burrowT = 0; burrowOff = .zero; burrowRot = 0 }
    }

    private func smooth(_ v: inout CGFloat, to t: CGFloat, rate: CGFloat, _ dt: CGFloat) {
        v += (t - v) * min(1, dt * rate)
    }

    // MARK: hlavní tik

    func update(_ dt: CGFloat, _ inp: Input) {
        clock += dt
        updateCommon(dt, inp)
        switch mode {
        case .ground: updateGround(dt, inp)
        case .toClimb: updateToClimb(dt)
        case .climb: updateClimb(dt)
        case .mantle: updateMantle(dt)
        case .grab: break
        case .air: updateAir(dt)
        case .balloon: updateBalloon(dt)
        case .parachute: updateParachute(dt)
        }
        smooth(&rot, to: rotTarget, rate: 14, dt)
        updateBall(dt)
    }

    private func updateCommon(_ dt: CGFloat, _ inp: Input) {
        if speechT > 0 { speechT -= dt; if speechT <= 0 { speech = nil } }
        // pružina zploštění
        qv += (-160 * q - 26 * qv) * dt
        q += qv * dt
        if abs(q) < 0.003 && abs(qv) < 0.03 { q = 0; qv = 0 }
        // mrkání
        blinkIn -= dt
        if blinkIn <= 0 { blinkT = 0.13; blinkIn = CGFloat.random(in: 2...5.5) }
        if blinkT > 0 { blinkT -= dt }
        // otáčí se za kurzorem (snímky nemají pohyblivé oči) a když píšeš, podívá se na tebe
        let typingStart = inp.typing && !typingBefore
        typingBefore = inp.typing
        if mode == .ground && speedNow < 5 * s && [.sit, .look, .happy, .bark, .meteor, .scratch].contains(act) {
            let dx = inp.mouse.x - pos.x
            let near = abs(dx) < 500 * s && abs(inp.mouse.y - pos.y) < 400 * s
            if (typingStart || (cfg.eyeTracking && near)) && abs(dx) > 30 * s && clock - lastTurn > 1.2 {
                let want: CGFloat = dx > 0 ? 1 : -1
                if want != facing { facing = want; lastTurn = clock }
            }
        }
        // vzdálená zvířata nehlídáme, jen tu a tam náhodný vtípek
        yOff = 0
        stretchExtra = 0
    }

    // MARK: země

    private func wantedSpeed() -> CGFloat {
        let base = 55 * s * CGFloat(cfg.walkSpeed) * daySpeed
        switch act {
        case .walk: return base
        case .follow: return base * 1.9
        case .squirrel: return sprinting ? 330 * s : 0
        case .sausage: return treatMoving ? base * 2.4 : 0
        case .toBed: return toBedMoving ? max(base * 2, 90 * s) : 0
        case .fetch: return fetchMoving ? max(base * 2.4, 100 * s) : 0
        case .fetchBall: return ballMoving ? (ballPhase == 0 ? max(base * 2.6, 140 * s) : max(base * 1.6, 70 * s)) : 0
        default: return 0
        }
    }

    private func updateGround(_ dt: CGFloat, _ inp: Input) {
        guard let top = surfaceTop() else { startAir(v: CGPoint(x: walkDir * 20, y: 0)); return }
        if surfaceId != 0, let w = env.window(surfaceId) {
            pos.x = w.frame.minX + relX
            if pos.x < w.frame.minX - 10 || pos.x > w.frame.maxX + 10 { startAir(v: .zero); return }
        }
        let jumping = act == .inBed || act == .outOfBed || (act == .toBed && bedJumpT >= 0)
        if !jumping && pos.y > top + DogRenderer.ground * s + 20 * s {
            // zem pod ní zmizela (aplikace na celou obrazovku schovala Dock): spadne dolů
            startAir(v: .zero)
            return
        }
        pos.y = top + DogRenderer.ground * s
        actT += dt
        rotTarget = 0
        if act == .inBed && bedSpot == nil {
            setAct(.stretch, 1.6)          // pelíšek zmizel (zvětšená Julie se do něj nevejde): vstane
        }
        if act == .toBed && bedJumpT >= 0 {
            if jumpArc(bedJumpT, dur: 0.55) {
                bedJumpT = -1
                setAct(.inBed, bedUntilClick ? 1e9 : bedStay)
                qv += 1.5
            }
        } else if act == .inBed, let r = bedRestPos {
            pos = r
        } else if act == .outOfBed {
            // nejdřív zvedne hlavu, pak vyskočí
            if actT < 0.5 {
                if let r = bedRestPos { pos = r; jumpFrom = r }
            } else {
                facing = jumpTo.x > jumpFrom.x ? 1 : -1
                if jumpArc(actT - 0.5, dur: 0.55) { setAct(.stretch, 1.6) }
            }
        }


        // vzbuzení
        if act == .sleep || act == .lie {
            let near = hitRect.insetBy(dx: -20 * s, dy: -20 * s).contains(inp.mouse)
            if near && cfg.eyeTracking == true && hover > 0.01 { setAct(.stretch, 1.6); say("Ráno? Už? 🥱") }
        }

        actSpecific(dt, inp)

        // pohyb
        let want = wantedSpeed()
        smooth(&speedNow, to: want, rate: sprinting ? 14 : (want > speedNow ? 6 : 9), dt)
        if speedNow > 2 {
            pos.x += walkDir * speedNow * dt
            facing = walkDir
            phase += speedNow * dt / (7 * s) * (1)
            pawT -= dt
            if cfg.mischief && pawT <= 0 {
                pawT = 0.55
                fx.paw(at: CGPoint(x: pos.x, y: top + 4), size: 12 * s, facing: facing)
            }
        } else {
            phase += dt * 1.2
        }
        let (lo, hi) = bounds()
        if act == .toBed || act == .inBed || act == .outOfBed || act == .fetch {
            // pelíšek stojí na Docku, k němu smí i kousek za běžnou hranici
        } else if surfaceId == 0 && (pos.x < lo - 2 || pos.x > hi + 2) {
            // mimo Dock (po pádu, hození…): vrať se pěšky, nepřeskakuj hranu
            if act != .walk { setAct(.walk, 99) }
            walkDir = pos.x < lo ? 1 : -1
        } else if pos.x < lo || pos.x > hi {
            pos.x = min(hi, max(lo, pos.x))
            if act == .walk && surfaceId != 0 && Int.random(in: 0..<100) < 45 {
                walkDir = -walkDir == 0 ? 1 : walkDir
                startAir(v: CGPoint(x: walkDir * 160 * s, y: 260 * s))
                say("Hop!", 1.2)
                return
            }
            walkDir = pos.x <= lo ? 1 : -1
            if act == .follow { setAct(.sit, 1.2) }
        }
        if surfaceId != 0, let w = env.window(surfaceId) { relX = pos.x - w.frame.minX }

        // konec činnosti
        if actT > actDur {
            if act == .dizzy || act == .petted { setAct(.shake, 0.75) }
            else if act == .inBed { leaveBed() }
            else { nextAct(inp) }
        }
    }

    private func actSpecific(_ dt: CGFloat, _ inp: Input) {
        let t = actT
        switch act {
        case .follow:
            let (flo, fhi) = bounds()
            let dx = min(fhi, max(flo, inp.mouse.x)) - pos.x
            if abs(dx) < 30 * s {
                if abs(inp.mouse.x - pos.x) < 90 * s {
                    setAct(.happy, 2.2)
                    say(["Haf haf!", "Jsem tu!", "Pohlaď mě!"].randomElement()!, 1.8)
                    if inp.mouse.y > pos.y + 80 * s { setAct(.sit, 3) }
                } else {
                    setAct(.sit, 3)
                    say("Dál nesmím, Dock končí!", 2)
                }
            } else {
                walkDir = dx > 0 ? 1 : -1
                if abs(dx) > 600 * s { phase += dt * 4 }
            }
        case .sleep:
            zzzT -= dt
            if zzzT <= 0 {
                zzzT = 1.7
            }
        case .lie:
            if t > actDur { setAct(.sleep, CGFloat.random(in: 9...22)) }
        case .bark:
            let k = Int(t / 0.42)
            if k != Int((t - dt) / 0.42) { barkFX() }
        case .scrabble:
            if Int(t * 6) != Int((t - dt) * 6) {
                fx.dirt(at: CGPoint(x: pos.x + facing * (half - 3) * pixel, y: (surfaceTop() ?? env.floorY) + 3), dir: facing, sizeScale: s, px: pixel)
            }
        case .dizzy:
            if Int(t * 3) != Int((t - dt) * 3) {
            }
        case .dig:
            digLogic(dt)
        case .toBed:
            toBedLogic(dt)
        case .fetch:
            fetchLogic(dt)
        case .fetchBall:
            fetchBallLogic(dt, inp)
        case .shake:
            break
        case .petted:
            heartT -= dt
            if heartT <= 0 {
                heartT = 0.55
                fx.heart(at: CGPoint(x: pos.x + facing * CGFloat.random(in: -10...16) * pixel, y: pos.y + 16 * pixel))
            }
        case .meteor:
            if Int(t * 3.2) != Int((t - dt) * 3.2) { fx.meteor(screenW: env.right, screenH: env.ceilY + 40) }
            if t > 1.5 && eggT == 0 { eggT = 1; say("Přeju si… pamlsek! 🌭", 4) }
        case .sausage:
            sausageLogic(dt, inp)
        case .squirrel:
            squirrelLogic(dt)
        default:
            break
        }
    }

    /// Hrabání: čtyři snímky, přední tlapky se střídají (nahoru dopředu → pod sebe dozadu).
    func digFrame(_ t: CGFloat, fps: CGFloat) -> String {
        let n = DogRenderer.frames["hrabe3"] != nil ? 4 : 2
        return "hrabe\(Int(t * fps) % n)"
    }

    // MARK: nora
    // 0 hrabe, 1 nakloní se čenichem dolů, 2 noří se hlavou napřed, 3 tunel pod zemí,
    // 4 vykoukne hlavou nahoru, 5 vyleze ven, 6 narovná se, 7 otřepe se

    private func ease(_ u: CGFloat) -> CGFloat { let v = max(0, min(1, u)); return v * v * (3 - 2 * v) }

    /// Výška páteře (střed trupu) nad tlapkami ve snímku, v pixelech obrázku.
    /// (Bere se výš než skutečná páteř: v díře mizí/objevuje se hlava a zvednutý ocas, ne břicho.)
    static var spineHeight: CGFloat { (DogRenderer.standHeight * 0.6).rounded() }
    /// Polovina délky stojící Julie (pixely obrázku); od ní se počítá tlama, tlapky, díry.
    var half: CGFloat { (DogRenderer.standWidth / 2).rounded() }

    /// Posun snímku tak, aby páteř procházela přesně středem díry `h` a nad zemí
    /// (při vylézání) / pod zemí (při zanořování) byl podíl `e` délky těla od čenichu.
    /// Přesně podle vykreslování: bod snímku p -> posun + zrcadlení(rotace(p)).
    private func spine(_ h: CGPoint, _ r: CGFloat, _ e: CGFloat) -> CGPoint {
        let len = DogRenderer.standWidth, half = len / 2
        let g = (DogRenderer.ground * s / pixel).rounded()
        let ys = -g + Pet.spineHeight
        let xc = half - e * len                // bod páteře, který je právě v díře
        let rx = xc * cos(r) - ys * sin(r)
        let ry = xc * sin(r) + ys * cos(r)
        return CGPoint(x: h.x - facing * rx, y: h.y - ry)
    }

    /// Středy děr vůči Julii (pixely obrázku): před čenichem a za ocasem.
    var holeFront: CGFloat { facing * (half - 6) }
    var holeBack: CGFloat { -facing * DogRenderer.standWidth / 2 }

    private func digLogic(_ dt: CGFloat) {
        burrowT += dt
        let t = burrowT
        let g = DogRenderer.ground * s / pixel
        let floor = surfaceTop() ?? env.floorY
        let front = CGPoint(x: holeFront, y: -g.rounded() - 1)    // díra před čenichem
        let back = CGPoint(x: holeBack, y: -g.rounded() - 1)      // díra za ocasem (při vylézání)
        let pawX = pos.x + facing * (half - 3) * pixel
        let tick = { (hz: CGFloat) -> Bool in Int(t * hz) != Int((t - dt) * hz) }
        burrowClip = burrowPhase >= 1 && burrowPhase <= 6
        switch burrowPhase {
        case 0:
            // očichá místo → hrabe → strčí čenich do díry → hrabe znovu, rychleji
            burrowRot = 0; burrowOff = .zero
            let backX = pos.x - facing * (half + 5) * pixel     // kam padá hlína (za Julii)
            if t < 0.7 {
                burrowFrame = "cuch"
            } else if t < 1.9 || (t >= 2.4 && t < 3.3) {
                let fast = t >= 2.4
                burrowFrame = digFrame(t, fps: fast ? 14 : 11)
                if t - dt < 0.7 {
                    lastHoleX = pos.x + front.x * pixel
                    fx.hole(at: lastHoleX, floorY: floor, px: pixel, grow: 2.6)
                    fx.mound(at: backX, floorY: floor, px: pixel, grow: 2.6)
                }
                if tick(fast ? 16 : 12) {
                    fx.dirtArc(from: CGPoint(x: pawX, y: floor + 2), to: backX + CGFloat.random(in: -6...6) * pixel, floorY: floor, px: pixel)
                }
                burrowJitter = 0
            } else {
                burrowFrame = "cuch"                 // čenich do díry
                burrowRot = -0.12
                burrowJitter = 0
            }
            if t > 3.3 { burrowPhase = 1; burrowT = 0; burrowJitter = 0 }
        case 1:
            let u = ease(t / 0.3)
            burrowFrame = digFrame(t, fps: 11)
            burrowRot = -0.7 * u
            let o = spine(front, -0.7, 0)
            burrowOff = CGPoint(x: o.x * u, y: o.y * u)
            if t > 0.3 { burrowPhase = 2; burrowT = 0 }
        case 2:
            let u = min(1, t / 0.8)
            burrowFrame = digFrame(t, fps: 12)
            burrowRot = -0.7
            burrowOff = spine(front, -0.7, u * 1.25)       // o kus dál, ať zmizí i zvednutý ocas
            if tick(8) { fx.dirt(at: CGPoint(x: pos.x + front.x * pixel, y: floor + 2), dir: facing, sizeScale: s, px: pixel) }
            if t > 0.85 {
                burrowPhase = 3; burrowT = 0
                let (lo, hi) = bounds()
                var x = CGFloat.random(in: lo...hi)
                for _ in 0..<6 where abs(x - pos.x) < 160 * s { x = CGFloat.random(in: lo...hi) }
                burrowTarget = x
                trailX = pos.x
            }
        case 3:
            // tunel: Julie není vidět, nad ní se kypří hlína
            let dir: CGFloat = burrowTarget > pos.x ? 1 : -1
            let step = 240 * s * dt
            if abs(burrowTarget - pos.x) <= step {
                pos.x = burrowTarget
                facing = forceFacing ?? (Bool.random() ? 1 : -1)
                walkDir = facing
                burrowPhase = 4; burrowT = 0
                // díra až podle NOVÉHO směru (dřív se brala podle směru pod zemí a byla o tělo vedle)
                let holeX = pos.x + holeBack * pixel
                lastHoleX = holeX
                fx.hole(at: holeX, floorY: floor, px: pixel, grow: 0.25)
                for _ in 0..<4 { fx.dirt(at: CGPoint(x: holeX, y: floor + 2), dir: -facing, sizeScale: s, px: pixel) }
            } else {
                pos.x += dir * step
                if abs(pos.x - trailX) > 34 * s {
                    trailX = pos.x
                    fx.dirt(at: CGPoint(x: pos.x, y: floor + 1), dir: -dir, sizeScale: s * 0.6, px: pixel)
                }
            }
            burrowOff = spine(front, -0.7, 1.25)
        case 4:
            let r = 0.95 + sin(t * 7) * 0.06
            burrowFrame = "stoji"
            burrowRot = r
            burrowOff = spine(back, r, min(0.38, -0.1 + t / 0.3 * 0.48))
            if t > 1.0 { burrowPhase = 5; burrowT = 0 }
        case 5:
            let u = ease(t / 0.6)
            let r = 0.95 - 0.7 * u
            phase += dt * 14
            burrowFrame = "chuze\(Int(phase / (.pi / 2)) & 3)"
            burrowRot = r
            burrowOff = spine(back, r, 0.38 + 0.62 * u)
            if tick(7) { fx.dirt(at: CGPoint(x: pos.x + back.x * pixel, y: floor + 2), dir: -facing, sizeScale: s, px: pixel) }
            if t > 0.6 { burrowPhase = 6; burrowT = 0 }
        case 6:
            let u = ease(t / 0.25)
            let o = spine(back, 0.25, 1)
            burrowFrame = "stoji"
            burrowRot = 0.25 * (1 - u)
            burrowOff = CGPoint(x: o.x * (1 - u), y: o.y * (1 - u))
            if t > 0.25 { burrowPhase = 7; burrowT = 0; burrowOff = .zero; burrowRot = 0 }
        default:
            // otřepání
            let u = min(1, t / 0.7)
            burrowFrame = "stoji"
            burrowRot = sin(t * 42) * 0.07 * (1 - u)
            if tick(10) && u < 0.8 {
                let side: CGFloat = Bool.random() ? 1 : -1
                fx.dirt(at: CGPoint(x: pos.x + side * CGFloat.random(in: 0...20) * pixel, y: floor + 14 * pixel), dir: -side, sizeScale: s * 0.7, px: pixel)
            }
            if t > 0.75 {
                burrowRot = 0
                setAct(.walk, CGFloat.random(in: 2...4))
            }
        }
    }

    /// Pamlsky: padají, leží na Docku, Julie k nim doběhne a sní je jeden po druhém.
    func dropTreat(at x: CGFloat, fromY y: CGFloat) {
        let lo = env.dockL + 20 * s, hi = env.dockR - 20 * s
        fx.dropSausage(x: min(hi, max(lo, x)), y: min(y, env.ceilY), size: 100 * s)
    }

    private func sausageLogic(_ dt: CGFloat, _ inp: Input) {
        let t = actT
        let floor = surfaceTop() ?? env.floorY
        if treatsToDrop > 0 {
            treatDropT -= dt
            if treatDropT <= 0 {
                treatDropT = 0.5
                treatsToDrop -= 1
                dropTreat(at: pos.x + CGFloat.random(in: -320...320) * s, fromY: env.ceilY)
            }
        }
        treatMoving = false
        if eatT > 0 { eatT -= dt; return }
        // nejbližší pamlsek (ležící má přednost před padajícím)
        var best: Sausage?
        var bestScore = CGFloat.infinity
        for sa in fx.sausages {
            let score = abs(sa.pos.x - pos.x) + (sa.landed ? 0 : (sa.pos.y - floor) * 0.3)
            if score < bestScore { best = sa; bestScore = score }
        }
        guard let b = best else {
            if treatsToDrop == 0 && t > 0.6 { setAct(.happy, 1.4) }
            return
        }
        let side: CGFloat = b.pos.x > pos.x ? 1 : -1
        let (lo, hi) = bounds()
        let targetX = min(hi, max(lo, b.pos.x - side * (half - 3) * pixel))
        let mouthX = pos.x + side * (half - 1) * pixel
        let low = b.pos.y < floor + DogRenderer.standHeight * 0.9 * pixel
        if abs(b.pos.x - mouthX) < 9 * pixel && low && b.landed {
            facing = side
            fx.eat(b)
            eatT = 0.5
            qv -= 1.5
            return
        }
        if abs(targetX - pos.x) > 3 * pixel {
            walkDir = targetX > pos.x ? 1 : -1
            treatMoving = true
        } else {
            facing = side
        }
        if t > 25 { fx.clearSausages(); setAct(.sit, 1) }
    }

    /// Veverka: zahlédne ji, ztuhne, štěkne a vystartuje plným sprintem (bez ohledu na nastavenou
    /// rychlost chůze), během běhu štěká; veverka uteče, Julie doběhne ke kraji Docku a ještě štěká.
    private func squirrelLogic(_ dt: CGFloat) {
        let t = actT
        let (lo, hi) = bounds()
        switch squirrelPhase {
        case 0:
            squirrelSide = pos.x < (lo + hi) / 2 ? 1 : -1
            let sx = squirrelSide > 0 ? hi + 60 * s : lo - 60 * s
            squirrelX = sx
            fx.showSquirrel(at: CGPoint(x: sx, y: env.floorY), size: 100 * s, fromRight: squirrelSide > 0)
            walkDir = squirrelSide
            facing = squirrelSide
            squirrelPhase = 1
            actT = 0
        case 1:
            // ztuhne a jednou štěkne
            facing = squirrelSide
            if t >= 0.15 && t - dt < 0.15 { barkFX() }
            if t > 0.7 { squirrelPhase = 2; actT = 0 }
        case 2:
            // sprint s vyplazeným jazykem (bez štěkání)
            walkDir = squirrelSide
            if abs(squirrelX - pos.x) < 260 * s || t > 8 {
                fx.squirrelFlees(toRight: squirrelSide > 0)
                squirrelPhase = 3
                actT = 0
            }
        case 3:
            // doběhne až ke kraji Docku
            walkDir = squirrelSide
            let edge = squirrelSide > 0 ? hi : lo
            if abs(edge - pos.x) < 4 || t > 3 { squirrelPhase = 4; actT = 0; speedNow = 0 }
        default:
            // oddechuje s jazykem venku
            facing = squirrelSide
            if t > 2.2 { setAct(.sit, 2) }
        }
    }

    /// Sprint (veverka) má pevnou rychlost, nastavená rychlost chůze ho nezpomalí.
    private var sprinting: Bool { act == .squirrel && (squirrelPhase == 2 || squirrelPhase == 3) }

    // MARK: výběr další činnosti

    func nextAct(_ inp: Input) {
        if heldTreatPos != nil && surfaceId == 0 { startFetch(); return }
        if wantBed && surfaceId == 0 { wantBed = false; goToBed(untilClick: true); return }
        // denní režim: v noci a večer víc odpočívá, ráno je čilejší
        let part = dayPart
        if bedX != nil && surfaceId == 0 && Int.random(in: 0..<100) < [35, 4, 6, 15][part] { goToBed(untilClick: false); return }
        if part == 0 && Int.random(in: 0..<100) < 40 { setAct(.lie, 3); return }
        if part == 1 && Int.random(in: 0..<100) < 20 { setAct(Bool.random() ? .stretch : .happy, 1.8); return }
        // občas si sama pohraje s míčkem, který leží na Docku
        if let b = ball, !b.carried, !ballHeldByUser, surfaceId == 0, Int.random(in: 0..<100) < 8 { startFetchBall(); return }
        // ležící pamlsek má přednost před vším ostatním
        if !fx.sausages.isEmpty && surfaceId == 0 { setAct(.sausage, 999); treatsToDrop = 0; return }
        if speedNow > 20 && act != .walk && act != .sniff { }
        let r = Int.random(in: 0..<100)
        let (lo, hi) = bounds()
        _ = (lo, hi)
        walkDir = Bool.random() ? 1 : -1
        if cfg.mischief {
            nextEgg -= actDur
        }
        if cfg.mischief && nextEgg <= 0 && surfaceId == 0 {
            nextEgg = CGFloat.random(in: 120...300)
            startEgg(nil)
            return
        }
        if r < 28 { setAct(.walk, CGFloat.random(in: 3...8)) }
        else if r < 40 { setAct(.sit, CGFloat.random(in: 3...6)) }
        else if r < 46 { setAct(.lie, 2) }
        else if r < 56 { setAct(.sniff, CGFloat.random(in: 2.5...5)) }
        else if r < 61 { setAct(.scratch, 2.2) }
        else if r < 66 { setAct(.stretch, 1.8) }
        else if r < 73 { setAct(.look, CGFloat.random(in: 2.5...4)) }
        else if r < 78 { setAct(.bark, 1.7); say(["Haf!", "Haf haf!", "Kdo to?!"].randomElement()!, 1.4) }
        else if r < 86 && abs(inp.mouse.x - pos.x) > 200 * s && cfg.eyeTracking { setAct(.follow, 9); say("Jdu za tebou!", 1.6) }
        else if r < 92 && cfg.mischief && surfaceId == 0 { setAct(.dig, 4.6) }
        else if cfg.windowPlatforms && startClimbIfPossible() { }
        else { setAct(.walk, CGFloat.random(in: 3...7)) }
    }

    func startEgg(_ which: Int?) {
        guard mode == .ground else { return }
        // 0 balónky, 1 veverka, 2 déšť pamlsků
        let n = which ?? Int.random(in: 0..<3)
        switch n {
        case 0: startBalloons()
        case 1: setAct(.squirrel, 30)
        default: rainTreats()
        }
    }

    // MARK: pelíšek

    /// Pelíšek stojí vedle pravého (nebo levého) konce Docku, dole ve výšce Docku.
    /// `bedSpot` = střed spodní hrany pelíšku; nastavuje ho aplikace podle Docku.
    var bedSpot: CGPoint?
    var bedX: CGFloat? { bedSpot?.x }
    /// O kolik výš nad dnem pelíšku leží (na polštáři), v pixelech obrázku.
    static let bedLift: CGFloat = 5
    private var jumpFrom = CGPoint.zero
    private var jumpTo = CGPoint.zero

    /// Kde je střed těla, když leží v pelíšku.
    private var bedRestPos: CGPoint? {
        guard let b = bedSpot else { return nil }
        // snímky jsou zarovnané podle hlavy (vpravo); klubíčko posunout na střed pelíšku
        let w = CGFloat(DogRenderer.frames["klubicko"]?.width ?? 44)
        let shift = (DogRenderer.standWidth / 2).rounded() - w / 2
        return CGPoint(x: b.x - facing * shift * pixel, y: b.y + Pet.bedLift * pixel + DogRenderer.ground * s)
    }
    /// Odkud z Docku do pelíšku skáče (kraj Docku blíž k pelíšku).
    private var bedEdge: CGPoint? {
        guard let b = bedSpot else { return nil }
        let (lo, hi) = bounds()
        return CGPoint(x: b.x > pos.x ? hi : lo, y: env.floorY + DogRenderer.ground * s)
    }

    /// Kliknutí na ikonu Pelíšek: spí → vzbudí se, jinak jde spát (a zůstane, dokud znovu neklikneš).
    func bedToggle() {
        if act == .outOfBed || (act == .toBed && bedJumpT >= 0) { return }
        if act == .inBed || (act == .toBed && mode == .ground) { leaveBed(); return }
        goToBed(untilClick: true)
    }

    func goToBed(untilClick: Bool) {
        guard bedX != nil else { return }
        if mode == .grab || mode == .balloon { return }
        if mode != .ground || surfaceId != 0 {
            wantBed = true
            if mode == .ground { startAir(v: CGPoint(x: 0, y: 150 * s)) }
            return
        }
        fx.hideSquirrel()
        setAct(.toBed, 999)
        bedUntilClick = untilClick
    }

    func leaveBed() {
        wantBed = false
        if act == .inBed, let e = bedEdge {
            // vyskočí z pelíšku zpátky na Dock
            jumpFrom = pos
            jumpTo = CGPoint(x: e.x, y: e.y)
            setAct(.outOfBed, 1.1)
        } else if act == .toBed {
            setAct(.sit, 1)
        }
    }

    /// Cesta do pelíšku: dojde po Docku na jeho kraj a odtud seskočí do pelíšku.
    private func toBedLogic(_ dt: CGFloat) {
        guard let edge = bedEdge, let b = bedSpot else { setAct(.sit, 1); return }
        if bedJumpT >= 0 {
            // skok obloukem do pelíšku
            bedJumpT += dt
            return
        }
        let dx = edge.x - pos.x
        toBedMoving = abs(dx) > 3 * pixel && bedPrepT < 0
        if toBedMoving {
            walkDir = dx > 0 ? 1 : -1
        } else {
            // u kraje: očichá pelíšek, jednou se otočí, pak skočí
            if bedPrepT < 0 { bedPrepT = 0; speedNow = 0 }
            bedPrepT += dt
            let toward: CGFloat = b.x > pos.x ? 1 : -1
            facing = (bedPrepT > 0.7 && bedPrepT < 1.0) ? -toward : toward
            if bedPrepT >= 1.2 {
                facing = toward
                jumpFrom = pos
                jumpTo = bedRestPos ?? pos
                bedJumpT = 0
                bedPrepT = -1
            }
        }
    }

    /// Poloha při skoku do pelíšku / z pelíšku (oblouk), vrací true, když je doskočeno.
    private func jumpArc(_ t: CGFloat, dur: CGFloat) -> Bool {
        let u = min(1, t / dur)
        let e = u * u * (3 - 2 * u)
        let peak = max(jumpFrom.y, jumpTo.y) + 16 * pixel
        let lin = jumpFrom.y + (jumpTo.y - jumpFrom.y) * e
        pos.x = jumpFrom.x + (jumpTo.x - jumpFrom.x) * e
        pos.y = lin + (peak - max(jumpFrom.y, jumpTo.y)) * sin(u * .pi) + (max(jumpFrom.y, jumpTo.y) - lin) * sin(u * .pi) * 0.6
        return u >= 1
    }

    // MARK: pamlsek u kurzoru (⌃⌥P)

    /// Jak vysoko dosáhne čenichem (pixely obrázku nad zemí): ve stoje a když se postaví na zadní.
    private var standReach: CGFloat { DogRenderer.standHeight + 1 }
    private var begReach: CGFloat { CGFloat(DogRenderer.frames["panacek1"]?.height ?? 46) - 3 }

    func fetchTreat() {
        if mode != .ground { return }            // ve vzduchu: po dopadu si ho všimne (nextAct)
        switch act {
        case .inBed: leaveBed()                  // vstane z pelíšku, pak si pro něj dojde
        case .dig, .outOfBed, .fetch: break
        case .toBed where bedJumpT >= 0: break
        default:
            if surfaceId != 0 { startAir(v: CGPoint(x: 0, y: 150 * s)); return }
            startFetch()
        }
    }

    private func startFetch() {
        fx.hideSquirrel()
        setAct(.fetch, 999)
        begTries = 0
        fetchPhase = 0
        fetchT = 0
    }

    private func fetchLogic(_ dt: CGFloat) {
        guard let tp = heldTreatPos else {
            if fetchPhase != 3 { setAct(.sit, 1) }     // pamlsek zmizel (pustil jsi ho)
            else { fetchT += dt; if fetchT > 0.8 { setAct(.happy, 1.2) } }
            return
        }
        fetchT += dt
        let floor = surfaceTop() ?? env.floorY
        let side: CGFloat = tp.x > pos.x ? 1 : -1
        let (lo, hi) = bounds()
        let targetX = min(hi, max(lo, tp.x - side * (half - 1) * pixel))
        let h = (tp.y - floor) / pixel                          // výška pamlsku nad zemí v pixelech obrázku
        let mouthX = pos.x + side * (half - 1) * pixel
        let underIt = abs(tp.x - mouthX) < 14 * pixel
        fetchMoving = false
        switch fetchPhase {
        case 0:   // jde pod pamlsek
            if abs(targetX - pos.x) > 3 * pixel {
                walkDir = targetX > pos.x ? 1 : -1
                fetchMoving = true
            } else {
                facing = side
                fetchPhase = 1; fetchT = 0
            }
        case 1:   // dosáhne?
            facing = side
            if abs(targetX - pos.x) > 6 * pixel { fetchPhase = 0; return }
            if underIt && h <= standReach { fx.takeHeld(); fetchPhase = 3; fetchT = 0 }
            else if underIt && h <= begReach { fetchPhase = 2; fetchT = 0 }
            else { fetchPhase = 4; fetchT = 0 }
        case 2:   // postaví se na zadní a chňapne
            if fetchT > 0.35 {
                if underIt && h <= begReach { fx.takeHeld(); fetchPhase = 3; fetchT = 0; qv -= 1.5 }
                else { fetchPhase = 4; fetchT = 0 }
            }
        case 4:   // panáčkuje, ale nedosáhne (když pamlsek mezitím snížíš, hned chňapne)
            if underIt && h <= begReach && fetchT > 0.2 { fx.takeHeld(); fetchPhase = 3; fetchT = 0; qv -= 1.5 }
            else if fetchT > 1.3 { fetchPhase = 5; fetchT = 0; begTries += 1 }
        case 5:   // sedí, kouká nahoru a čeká; znovu zkusí, když pamlsek přiblížíš
            facing = side
            if abs(targetX - pos.x) > 8 * pixel { fetchPhase = 0; fetchT = 0 }
            else if underIt && h <= begReach { fetchPhase = 1 }
            else if fetchT > 2.5 && begTries < 3 { fetchPhase = 4; fetchT = 0 }   // po 3 pokusech už jen čeká
        default:
            break
        }
    }

    private var fetchFrame: String {
        let beg0 = DogRenderer.frames["panacek0"] != nil ? "panacek0" : "sedi"
        let beg1 = DogRenderer.frames["panacek1"] != nil ? "panacek1" : "stekot"
        switch fetchPhase {
        case 0: return speedNow > 6 * s ? walkFrame : "stoji"
        case 2: return beg1
        case 3: return fetchT < 0.25 ? "stekot" : "sedi"
        case 4: return Int(fetchT / 0.4) % 2 == 0 ? beg0 : beg1
        case 5: return "sedi"
        default: return "stoji"
        }
    }

    /// Potřebuje Julie zrovna znát okna ostatních aplikací? (lezení, jízda na okně, pád)
    var needsWindows: Bool {
        surfaceId != 0 || mode == .toClimb || mode == .climb || mode == .mantle || mode == .air || mode == .balloon || mode == .parachute
    }

    /// Děje se něco, co potřebuje plynulých 60 snímků/s?
    var needsFastFrames: Bool {
        if mode != .ground { return true }
        if [.dig, .squirrel, .happy, .outOfBed, .shake, .bark].contains(act) { return true }
        if act == .toBed && (bedJumpT >= 0) { return true }
        if let b = ball, !b.carried, !b.onGround || abs(b.vel.x) > 1 { return true }
        return q != 0
    }
    /// Stojí Julie v klidu (sedí, leží, spí, v pelíšku)?
    var isResting: Bool {
        mode == .ground && speedNow < 1 && [.sit, .lie, .sleep, .inBed, .petted, .look, .sniff].contains(act)
    }

    /// Po změně monitorů: zrušit rozpracované skoky a lezení, postavit ji bezpečně na Dock.
    func resetForScreenChange() {
        if mode != .ground || [.toBed, .outOfBed, .inBed].contains(act) || surfaceId != 0 {
            mode = .ground
            surfaceId = 0
            rot = 0; rotTarget = 0
            setAct(.sit, 1)
        }
        let (lo, hi) = bounds()
        pos.x = min(hi, max(lo, pos.x))
        pos.y = env.floorY + DogRenderer.ground * s
        if var b = ball { b.carried = false; b.pos.x = min(env.dockR - 10, max(env.dockL + 10, b.pos.x)); b.pos.y = env.floorY + 40; ball = b }
    }

    /// Jeden krok světa po kouscích nejvýš 1/30 s (při nižším počtu snímků se nic nezpomalí).
    static func step(_ pet: Pet, _ fx: Effects, _ dt: CGFloat, _ inp: Input, floorY: CGFloat) {
        var remaining = min(dt, 0.5)
        while remaining > 0.0001 {
            let h = min(remaining, 1.0 / 30)
            pet.update(h, inp)
            fx.update(h, floorY: floorY)
            remaining -= h
        }
    }

    // MARK: denní režim

    /// 0 noc (22–7), 1 ráno (7–10), 2 den, 3 večer (19–22)
    private var dayPartCache = (part: 2, at: -999.0 as CGFloat)
    var dayPart: Int {
        if clock - dayPartCache.at > 60 || dayPartCache.at < 0 {
            let h = Calendar.current.component(.hour, from: Date())
            let part = (h >= 22 || h < 7) ? 0 : (h < 10 ? 1 : (h >= 19 ? 3 : 2))
            dayPartCache = (part, clock)
        }
        return dayPartCache.part
    }
    var daySpeed: CGFloat { [0.75, 1.15, 1.0, 0.9][dayPart] }
    /// Jak dlouho zůstane v pelíšku, když si tam zajde sama.
    var bedStay: CGFloat {
        switch dayPart {
        case 0: return CGFloat.random(in: 90...240)
        case 3: return CGFloat.random(in: 40...100)
        default: return CGFloat.random(in: 25...70)
        }
    }

    // MARK: Claude Code (krátké reakce, bez bublin)

    func reactToClaude(_ tok: String) {
        guard mode == .ground else { return }
        // Claude skončil nebo čeká na tebe a Julie spí v pelíšku (poslal ji tam dlouhou prací): vstane
        if (tok == "done" || tok == "notify") && act == .inBed && !bedUntilClick { leaveBed(); return }
        let busy: [Act] = [.dig, .inBed, .toBed, .outOfBed, .fetch, .fetchBall, .squirrel, .sausage, .petted, .shake, .dizzy]
        if busy.contains(act) { return }
        let important = tok == "notify" || tok == "done"
        if !important && clock - lastClaudeReact < 6 { return }
        if tok == "notify" && act == .bark { return }
        lastClaudeReact = clock
        switch tok {
        case "think": setAct(.sit, 2.5)                // pozorně si sedne
        case "bash", "edit": setAct(.scrabble, 2.5)    // hrabe
        case "read": setAct(.sniff, 2.5)               // čuchá
        case "web", "task": setAct(.look, 2)           // rozhlíží se
        case "notify": setAct(.bark, 2)                // Claude na tebe čeká: štěká
        case "done":                                    // hotovo: přinese míček, nebo radostně vyskočí
            if let b = ball, !b.carried, !ballHeldByUser, surfaceId == 0 { startFetchBall() } else { setAct(.happy, 1.5) }
        default: break
        }
    }

    // MARK: míček

    struct Ball {
        var pos: CGPoint
        var vel: CGPoint
        var onGround = false
        var carried = false
    }
    static let ballR: CGFloat = 3        // poloměr v pixelech obrázku

    /// Hod míčkem (zkratka ⌃⌥M nebo myší): Julie pro něj doběhne a přinese ho zpátky pod kurzor.
    func throwBall(from p: CGPoint, vel v: CGPoint) {
        ballHeldByUser = false
        ball = Ball(pos: p, vel: v)
        guard mode == .ground else { return }      // ve vzduchu: po dopadu si ho všimne (nextAct)
        switch act {
        case .inBed: leaveBed()
        case .dig, .outOfBed, .fetch: break
        case .toBed where bedJumpT >= 0: break
        default:
            if surfaceId != 0 { startAir(v: CGPoint(x: 0, y: 150 * s)); return }
            startFetchBall()
        }
    }

    /// Míček drží myš (táhneš ho); Julie ho případně pustí z tlamy.
    func holdBall(at p: CGPoint) {
        ballHeldByUser = true
        if ball == nil { ball = Ball(pos: p, vel: .zero) }
        ball?.carried = false
        ball?.pos = p
        ball?.vel = .zero
        if act == .fetchBall && ballPhase > 0 { ballPhase = 0; ballT = 0 }
    }

    func startFetchBall() {
        fx.hideSquirrel()
        setAct(.fetchBall, 999)
        ballPhase = -1          // úklona k hraní, pak za míčkem
        ballT = 0
    }

    private func updateBall(_ dt: CGFloat) {
        guard var b = ball, !ballHeldByUser else { return }
        let r = Pet.ballR * pixel
        if b.carried {
            b.pos = CGPoint(x: pos.x + facing * half * pixel,
                            y: pos.y - DogRenderer.ground * s + DogRenderer.standHeight * 0.55 * pixel + yOff)
            b.vel = .zero
        } else {
            b.vel.y -= 1700 * s * dt
            b.pos.x += b.vel.x * dt
            b.pos.y += b.vel.y * dt
            let lo = env.dockL + 8 * pixel, hi = env.dockR - 8 * pixel
            if b.pos.x < lo { b.pos.x = lo; b.vel.x = abs(b.vel.x) * 0.5 }
            if b.pos.x > hi { b.pos.x = hi; b.vel.x = -abs(b.vel.x) * 0.5 }
            let rest = env.floorY + r
            if b.pos.y <= rest {
                b.pos.y = rest
                if b.vel.y < -90 * s {
                    b.vel.y = -b.vel.y * 0.5          // míček se odrazí (on ano, Julie ne)
                    b.vel.x *= 0.8
                    b.onGround = false
                } else {
                    b.vel.y = 0
                    b.onGround = true
                }
            } else {
                b.onGround = false
            }
            if b.onGround {
                b.vel.x *= max(0, 1 - 2.2 * dt)       // dokutálí se
                if abs(b.vel.x) < 4 { b.vel.x = 0 }
            }
            if b.pos.y > env.ceilY - r { b.pos.y = env.ceilY - r; b.vel.y = -abs(b.vel.y) * 0.4 }
        }
        ball = b
    }

    private func fetchBallLogic(_ dt: CGFloat, _ inp: Input) {
        guard let b = ball else { setAct(.sit, 1); return }
        ballT += dt
        ballMoving = false
        let (lo, hi) = bounds()
        switch ballPhase {
        case -1:  // úklona k hraní
            facing = b.pos.x > pos.x ? 1 : -1
            if ballT > 0.6 { ballPhase = 0; ballT = 0 }
        case 0:   // za míčkem
            if ballHeldByUser { facing = b.pos.x > pos.x ? 1 : -1; return }   // čeká, až ho hodíš
            let side: CGFloat = b.pos.x > pos.x ? 1 : -1
            let targetX = min(hi, max(lo, b.pos.x - side * (half - 1) * pixel))
            let mouthX = pos.x + side * (half - 1) * pixel
            if abs(b.pos.x - mouthX) < 6 * pixel && b.pos.y < env.floorY + 10 * pixel && abs(b.vel.x) < 220 * s {
                facing = side
                ball?.carried = true
                ballPhase = 1; ballT = 0
                qv -= 1
            } else if abs(targetX - pos.x) > 3 * pixel {
                walkDir = targetX > pos.x ? 1 : -1
                ballMoving = true
            } else {
                facing = side                         // počká, až míček dopadne nebo se dokutálí
            }
            if ballT > 20 { setAct(.sit, 1) }
        case 1:   // nese míček k tobě (pod kurzor)
            let tx = min(hi, max(lo, inp.mouse.x))
            if abs(tx - pos.x) > 4 * pixel && ballT < 15 {
                walkDir = tx > pos.x ? 1 : -1
                ballMoving = true
            } else {
                ball?.carried = false                // položí ho
                ball?.vel = CGPoint(x: facing * 30 * s, y: 0)
                ballPhase = 2; ballT = 0
            }
        default:  // sedí a čeká na další hod
            if abs(inp.mouse.x - pos.x) > 30 * s { facing = inp.mouse.x > pos.x ? 1 : -1 }
            if ballT > 12 { setAct(.lie, 3) }
        }
    }

    private var ballFrame: String {
        let moving = speedNow > 6 * s
        switch ballPhase {
        case -1: return "protahuje"
        case 0: return moving ? walkFrame : "stoji"
        case 1:
            if DogRenderer.frames["mic_stoji"] == nil { return moving ? walkFrame : "stoji" }
            if !moving { return "mic_stoji" }
            return Int((phase * 1.3 / (.pi / 2)).rounded(.down)) & 1 == 0 ? "mic_chuze0" : "mic_chuze1"
        default: return "sedi"
        }
    }

    func rainTreats() {
        setAct(.sausage, 999)
        treatsToDrop = 6
        treatDropT = 0
    }

    /// Pamlsek z menu: spadne z místa kurzoru a Julie si pro něj doběhne.
    func giveTreat(_ mouse: CGPoint) {
        dropTreat(at: mouse.x, fromY: mouse.y)
        if mode == .ground && act != .sausage && act != .dig {
            if surfaceId != 0 { startAir(v: CGPoint(x: 0, y: 150 * s)); return }
            setAct(.sausage, 999)
            treatsToDrop = 0
        }
    }

    func startBalloons() {
        guard mode == .ground || mode == .air else { return }
        mode = .balloon
        balloons = 3
        balloonT = 0
        vel = .zero
        say("Éééé… vzlétám! 🎈", 2.5)
        surfaceId = 0
        pos.y += hangDrop
    }

    // MARK: lezení

    @discardableResult
    func startClimbIfPossible() -> Bool {
        guard surfaceId == 0, let base = surfaceTop() else { return false }
        env.refreshWindows(force: true)
        var cands: [WinInfo] = []
        for w in env.windows {
            let fits = w.frame.minY <= base + 60 * s && w.top >= base + 70 * s && w.top <= env.ceilY - 110 * s
            if fits && climbSide(w) != nil && !env.covered(x: w.frame.midX, y: w.top, below: w.id) { cands.append(w) }
        }
        guard let w = cands.randomElement() else { return false }
        climbId = w.id
        toClimbT = 0
        mode = .toClimb
        speedNow = 0
        say("Támhle půjdu nahoru!", 1.8)
        return true
    }

    /// Z které strany se dá na okno vylézt, aniž by Julie opustila Dock (nil = nejde).
    private func climbSide(_ w: WinInfo) -> CGFloat? {
        let ok: (CGFloat) -> Bool = { f in
            let x = self.standX(w, f: f)
            return x >= self.env.dockL + 20 * self.s && x <= self.env.dockR - 20 * self.s
        }
        let pref: CGFloat = pos.x < w.frame.midX ? 1 : -1
        if ok(pref) { return pref }
        if ok(-pref) { return -pref }
        return nil
    }

    private func standX(_ w: WinInfo, f: CGFloat) -> CGFloat {
        f > 0 ? w.frame.minX - 24 * s : w.frame.maxX + 24 * s
    }

    private func updateToClimb(_ dt: CGFloat) {
        guard let w = env.window(climbId), let top = surfaceTop() else { mode = .ground; setAct(.sit, 1); return }
        toClimbT += dt
        pos.y = top + DogRenderer.ground * s
        rotTarget = 0
        guard let side = climbSide(w) else { mode = .ground; setAct(.sit, 1); return }
        climbF = side
        let tx = standX(w, f: climbF)
        if toClimbT > 14 { mode = .ground; setAct(.sit, 1); return }
        let dx = tx - pos.x
        walkDir = dx > 0 ? 1 : -1
        facing = walkDir
        let sp = 55 * s * CGFloat(cfg.walkSpeed) * 2
        let step = min(abs(dx), sp * dt)
        pos.x += walkDir * step
        phase += step / (7 * s)
        speedNow = sp
        if abs(dx) < 4 {
            mode = .climb
            facing = climbF
            speedNow = 0
        }
    }

    private func updateClimb(_ dt: CGFloat) {
        guard let w = env.window(climbId) else { startAir(v: .zero); return }
        facing = climbF
        rotTarget = .pi / 2
        pos.x = standX(w, f: climbF)
        let sp = 70 * s * CGFloat(cfg.walkSpeed)
        pos.y += sp * dt
        phase += sp * dt / (6 * s)
        speedNow = sp
        if pos.y + 40 * s >= w.top {
            mode = .mantle
            mantleT = 0
            mantleFrom = CGPoint(x: pos.x - w.frame.minX, y: pos.y - w.top)
            let ex = climbF > 0 ? 30 * s : w.frame.width - 30 * s
            mantleTo = CGPoint(x: ex, y: DogRenderer.ground * s)
        }
    }

    private func updateMantle(_ dt: CGFloat) {
        guard let w = env.window(climbId) else { startAir(v: .zero); return }
        mantleT += dt
        let u = min(1, mantleT / 0.65)
        let e = u * u * (3 - 2 * u)
        let rx = mantleFrom.x + (mantleTo.x - mantleFrom.x) * e
        let ry = mantleFrom.y + (mantleTo.y - mantleFrom.y) * e + sin(u * .pi) * 14 * s
        pos = CGPoint(x: w.frame.minX + rx, y: w.top + ry)
        rotTarget = (1 - e) * .pi / 2
        rot = rotTarget
        phase += dt * 9
        if u >= 1 {
            mode = .ground
            surfaceId = w.id
            relX = rx
            walkDir = climbF
            facing = climbF
            rot = 0
            rotTarget = 0
            setAct(.look, 3)
            say(["Hurá, nahoře!", "Tady je vidět!", "Jsem král okna 👑"].randomElement()!, 2.4)
            qv -= 3
        }
    }

    // MARK: vzduch

    func startAir(v: CGPoint) {
        mode = .air
        vel = v
        surfaceId = 0
        bounces = 0
        speedNow = 0
    }

    private func updateAir(_ dt: CGFloat) {
        let g = 2300 * s * CGFloat(cfg.gravity)
        let prevFeet = pos.y - DogRenderer.ground * s
        vel.y -= g * dt
        pos.x += vel.x * dt
        pos.y += vel.y * dt
        if abs(vel.x) > 40 * s { facing = vel.x > 0 ? 1 : -1 }
        rotTarget = max(-0.8, min(0.8, atan2(vel.y, max(60, abs(vel.x))) * 0.55))
        stretchExtra = min(0.4, hypot(vel.x, vel.y) / 4200)
        phase += dt * 12

        let lo = env.left + 70 * s, hi = env.right - 70 * s
        if pos.x < lo { pos.x = lo; vel.x = 0 }
        if pos.x > hi { pos.x = hi; vel.x = 0 }
        let ceil = env.ceilY + 200 - 60 * s
        if pos.y > ceil { pos.y = ceil; vel.y = min(0, vel.y) }

        let feet = pos.y - DogRenderer.ground * s
        if vel.y <= 0 {
            var landed: (Int, CGFloat)?
            if cfg.windowPlatforms {
                for w in env.windows where prevFeet >= w.top - 3 && feet <= w.top
                    && pos.x > w.frame.minX + 8 * s && pos.x < w.frame.maxX - 8 * s
                    && !env.covered(x: pos.x, y: w.top, below: w.id) {
                    landed = (w.id, w.top)
                    break
                }
            }
            if landed == nil && feet <= env.floorY { landed = (0, env.floorY) }
            if let (id, y) = landed {
                let hit = abs(vel.y)
                pos.y = y + DogRenderer.ground * s
                surfaceId = id
                if id != 0, let w = env.window(id) { relX = pos.x - w.frame.minX }
                mode = .ground
                vel = .zero
                rot = 0; rotTarget = 0
                speedNow = 0
                q = 0; qv = min(3.5, hit / (900 * s))
                if hit > 1500 * s {
                    setAct(.dizzy, 0.9)      // tvrdý dopad: chvíli poleží, pak se otřepe
                } else {
                    setAct(.shake, 0.75)
                }
            }
        }
    }

    private func updateBalloon(_ dt: CGFloat) {
        balloonT += dt
        let lift: CGFloat
        switch balloons {
        case 3: lift = 75
        case 2: lift = 20
        case 1: lift = -55
        default: lift = -400
        }
        let target = lift * s
        vel.y += (target - vel.y) * min(1, dt * 1.6)
        pos.y += vel.y * dt
        pos.x += sin(balloonT * 1.4) * 22 * s * dt
        rotTarget = sin(balloonT * 1.7) * 0.1
        facing = cos(balloonT * 0.4) > 0 ? 1 : -1
        phase += dt * 6
        let lo = env.left + 70 * s, hi = env.right - 70 * s
        pos.x = min(hi, max(lo, pos.x))
        // praskání
        let popAt: [CGFloat] = [5.5, 8.0, 10.5]
        let ceil = env.ceilY + 100 * s
        if balloons > 0 {
            let idx = 3 - balloons
            if balloonT > popAt[idx] || pos.y > ceil {
                if balloonT > popAt[idx] - 3 || pos.y > ceil {
                    balloons -= 1
                    if balloons == 0 { say("Uáááá!", 1.8) } else { say("Au, balónek!", 1.5) }
                    balloonT = max(balloonT, popAt[idx])
                }
            }
        }
        if balloons == 0 { pos.y -= hangDrop; rot = 0; startAir(v: CGPoint(x: 0, y: vel.y)) }
    }

    // MARK: chycení myší

    func beginGrab(_ mouse: CGPoint) {
        if ball?.carried == true { ball?.carried = false; ball?.vel = .zero }
        mode = .grab
        surfaceId = 0
        rot = 0
        rotTarget = 0
        phi = 0; phiV = 0
        lastMouse = mouse
        cursorVX = 0
        history = [(CGFloat(CACurrentMediaTime()), mouse)]
        speedNow = 0
        if act == .squirrel { fx.hideSquirrel() }
        fx.clearSausages()
        balloons = 0
        say("Haf?!", 1.5)
        act = .sit
    }

    func dragTo(_ mouse: CGPoint, _ dt: CGFloat) {
        let vx = (mouse.x - lastMouse.x) / max(dt, 0.001)
        cursorVX += (vx - cursorVX) * min(1, dt * 12)
        lastMouse = mouse
        let target = max(-0.9, min(0.9, -cursorVX * 0.0011))
        phiV += (-70 * (phi - target) - 5.5 * phiV) * dt
        phi += phiV * dt
        rot = phi * facing
        rotTarget = rot
        pos = mouse
        history.append((CGFloat(CACurrentMediaTime()), mouse))
        if history.count > 12 { history.removeFirst() }
    }

    /// Při visení je `pos` u krku; tělo je o tolik níž.
    private var hangDrop: CGFloat { 18 * pixel }

    func release() {
        let now = CGFloat(CACurrentMediaTime())
        let recent = history.filter { now - $0.0 < 0.1 }
        var v = CGPoint.zero
        if let a = recent.first, let b = recent.last, b.0 - a.0 > 0.01 {
            v = CGPoint(x: (b.1.x - a.1.x) / (b.0 - a.0), y: (b.1.y - a.1.y) / (b.0 - a.0))
        }
        let m = hypot(v.x, v.y)
        let maxV = 3600 * s
        if m > maxV { v = CGPoint(x: v.x / m * maxV, y: v.y / m * maxV) }
        // vysoko (nad polovinou širokoúhlé / nad třetinou obrazovky na výšku) → padáček
        let f = env.screen.frame
        let limit = f.height * (f.width >= f.height ? 0.5 : 1.0 / 3.0)
        if pos.y - f.minY > limit {
            startParachute(v)
            return
        }
        pos.y -= hangDrop
        rot = 0
        startAir(v: v)
        if m > 900 * s { say("Wíííí!", 1.6) }
    }

    // MARK: padáček

    var chuteT: CGFloat = 0          // čas od puštění
    var chuteOpen: CGFloat = 0       // 0…1 jak je padáček rozevřený
    var chuteLanded: CGFloat = -1    // ≥ 0: přistála, padáček splaskává

    func startParachute(_ v: CGPoint) {
        mode = .parachute
        surfaceId = 0
        vel = CGPoint(x: v.x * 0.5, y: min(v.y * 0.4, 200 * s))
        chuteT = 0
        chuteOpen = 0
        chuteLanded = -1
        rot = 0; rotTarget = 0
    }

    /// Visí na padáčku za obojek (pos = krk): pomalu klesá, houpe se, vítr ji trochu unáší.
    private func updateParachute(_ dt: CGFloat) {
        chuteT += dt
        if chuteLanded >= 0 {
            // přistála: padáček splaskne, pak se otřepe
            chuteLanded += dt
            chuteOpen = max(0, 1 - chuteLanded / 0.5)
            if chuteLanded > 0.5 {
                mode = .ground
                chuteLanded = -1
                setAct(.shake, 0.75)
            }
            return
        }
        chuteOpen = min(1, chuteT / 0.35)
        let fall = max(60, 120 * s)
        let targetVY = -fall * (0.25 + 0.75 * chuteOpen)
        vel.y += (targetVY - vel.y) * min(1, dt * (chuteOpen > 0.5 ? 3 : 1.2))
        vel.x += (sin(chuteT * 0.7) * 30 * s - vel.x) * min(1, dt * 0.8)      // vítr
        pos.x += vel.x * dt
        pos.y += vel.y * dt
        rotTarget = sin(chuteT * 2.2) * 0.12                                    // houpání
        let lo = env.left + 40 * s, hi = env.right - 40 * s
        pos.x = min(hi, max(lo, pos.x))
        // kde má tlapky (visí pod krkem)
        let bodyBelow = (CGFloat(DogRenderer.frames["visi"]?.height ?? 40) - DogRenderer.neckFromTop) * pixel
        let feet = pos.y - bodyBelow
        var landY: CGFloat?
        var landId = 0
        if cfg.windowPlatforms {
            for w in env.windows where feet <= w.top && feet >= w.top - 12 * s
                && pos.x > w.frame.minX + 8 * s && pos.x < w.frame.maxX - 8 * s
                && !env.covered(x: pos.x, y: w.top, below: w.id) {
                landY = w.top; landId = w.id
                break
            }
        }
        if landY == nil && feet <= env.floorY { landY = env.floorY }
        if let y = landY {
            surfaceId = landId
            if landId != 0, let w = env.window(landId) { relX = pos.x - w.frame.minX }
            pos.y = y + DogRenderer.ground * s
            rot = 0; rotTarget = 0
            vel = .zero
            chuteLanded = 0
        }
    }

    func poke() {
        guard mode == .ground, act != .inBed else { return }
        if act == .sleep || act == .lie { setAct(.stretch, 1.6); say("Hm? Už je ráno? 🥱", 2) ; return }
        setAct(.bark, 1.3)
        say(["Haf!", "Haf haf!", "Pamlsek? 🌭", "Nešahat… no dobře, šahat."].randomElement()!, 1.8)
        qv += 3
    }

    func petted() {
        guard mode == .ground else { return }
        if act == .inBed {
            fx.heart(at: CGPoint(x: pos.x, y: pos.y + 12 * pixel))
            return
        }
        if act == .dig || act == .sausage || act == .squirrel { return }
        if act == .petted { actDur = max(actDur, actT + 2.5); return }
        setAct(.petted, 3)
        heartT = 0
        say(["Hm, to je ono…", "Ještě!", "Julie je hodná holka 💛"].randomElement()!, 2)
    }

    func call(to mouse: CGPoint) {
        if mode == .grab || mode == .balloon { return }
        if mode != .ground {
            if mode == .air { return }
            startAir(v: .zero)
            return
        }
        if surfaceId != 0 { startAir(v: CGPoint(x: 0, y: 200 * s)); return }
        fx.clearSausages(); fx.hideSquirrel()
        setAct(.follow, 14)
        say("Už běžím!", 1.5)
    }

    // MARK: snímky

    private var walkFrame: String { "chuze\(Int((phase * 1.3 / (.pi / 2)).rounded(.down)) & 3)" }

    func buildPose() -> DogPose {
        var p = DogPose()
        p.rot = rot
        p.squash = max(-0.2, min(0.5, q))
        p.stretch = 1 + stretchExtra
        switch mode {
        case .grab:
            p.frame = "visi"; p.hang = true; p.stretch = 1
        case .air:
            p.frame = "pada"
        case .parachute:
            if chuteLanded >= 0 {
                p.frame = "stoji"                 // stojí, padáček za ní splaskává
                p.chute = chuteOpen
                p.chuteLanded = true
            } else {
                p.frame = "visi"; p.hang = true
                p.chute = chuteOpen
            }
        case .balloon:
            p.frame = "visi"; p.hang = true
            p.balloons = balloons
            p.balloonSway = sin(balloonT * 1.7) * 0.5
        case .climb, .toClimb, .mantle:
            p.frame = walkFrame
        case .ground:
            p.frame = groundFrame(&p)
        }
        return p
    }

    /// Klubíčko v pelíšku (když chybí snímky, aspoň leží).
    private func curl(awake: Bool) -> String {
        if awake { return DogRenderer.frames["klubicko_hlava"] != nil ? "klubicko_hlava" : "lezi" }
        return DogRenderer.frames["klubicko"] != nil ? "klubicko" : "spi"
    }

    private func groundFrame(_ p: inout DogPose) -> String {
        let t = actT
        let moving = speedNow > 6 * s
        let alt = Int(clock * 8) % 2
        switch act {
        case .toBed where bedJumpT >= 0:
            return "pada"
        case .toBed where bedPrepT >= 0:
            return bedPrepT < 0.7 ? "cuch" : "stoji"
        case .outOfBed:
            return t < 0.5 ? curl(awake: true) : "pada"
        case .fetch:
            return fetchFrame
        case .fetchBall:
            return ballFrame
        case .walk, .follow, .sausage, .squirrel, .toBed:
            if moving && sprinting {
                // cval: let s nataženýma nohama a dopad, s poskakováním
                let g = (clock * 4.2).truncatingRemainder(dividingBy: 1)
                let tongue = DogRenderer.frames["beh0"] != nil
                if g < 0.5 { yOff = sin(g * 2 * .pi) * 5 * pixel; return tongue ? "beh0" : "pada" }
                return tongue ? "beh1" : "chuze1"
            }
            if moving { return walkFrame }
            if act == .squirrel {
                if squirrelPhase == 1 { return t > 0.12 && t < 0.4 ? "stekot" : "stoji" }
                if squirrelPhase == 4 {
                    p.squash = abs(sin(clock * 9)) * 0.05         // rychle oddechuje
                    return DogRenderer.frames["funi"] != nil ? "funi" : "stoji"
                }
                return "stoji"
            }
            if act == .sausage { return eatT > 0 ? "cuch" : "sedi" }
            if act == .follow { return "sedi" }
            return "stoji"
        case .sit, .meteor: return "sedi"
        case .lie: return "lezi"
        case .sleep:
            p.squash = 0.03 + sin(clock * 2) * 0.03
            return "spi"
        case .sniff: return "cuch"
        case .scratch: return alt == 0 ? "drbe0" : "drbe1"
        case .stretch: return "protahuje"
        case .bark:
            let k = (t / 0.42).truncatingRemainder(dividingBy: 1)
            return k < 0.4 ? "stekot" : "stoji"
        case .look: return "stoji"
        case .dig:
            yOff = burrowJitter * pixel
            p.rot = burrowRot
            p.offset = burrowOff
            p.clipGround = burrowClip
            p.hidden = burrowPhase == 3
            return burrowFrame
        case .scrabble:
            return digFrame(clock, fps: 11)
        case .happy:
            let hop = abs(sin(t * 8))
            yOff = hop * 8 * s
            return hop > 0.35 ? "skace" : "stoji"
        case .dizzy:
            return "lezi"
        case .shake:
            let u = min(1, t / 0.7)
            p.rot = sin(t * 42) * 0.08 * (1 - u)
            return "stoji"
        case .petted:
            return "lezi"
        case .inBed:
            return curl(awake: t < 1.6)
        }
    }
}
