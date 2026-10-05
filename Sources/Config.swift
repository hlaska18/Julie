import Cocoa

/// Nastavení uložené v ~/.jezevcik/jezevcik.json (chybějící klíče dostanou výchozí hodnotu).
struct Config: Codable {
    var size: Double = 80           // šířka psa v pixelech (48–200)
    var walkSpeed: Double = 1.0
    var gravity: Double = 1.0
    var claudeWatch = true
    var eyeTracking = true
    var windowPlatforms = true
    var mischief = true
    var dockWidth: Double = 0       // 0 = zjistit samo; jinak pevná šířka Docku v bodech
    var bedX: Double = 0            // nepoužívá se (pelíšek stojí vedle Docku)
    var showInFullscreen = false    // ukazovat Julii i přes aplikace na celé obrazovce (Karel nechce)
    var autostart = false           // spouštět po přihlášení (LaunchAgent); nový uživatel volí v úvodním okně
    var bedDX: Double?              // pelíšek přetažený myší: posun od pravého konce Docku
    var bedDY: Double?              //   a výška spodní hrany nad spodkem obrazovky
    var pausedUntil: Double?        // uspaná (schovaná) do tohoto času (sekundy od 1970)
    var pausedForever = false       // uspaná, dokud ji Karel zase nezapne (i po restartu Macu)
    var hideOnExternalMain = true   // schovat, když je hlavní obrazovka externí (projektor) a MacBook je zapnutý
    var breakReminder = false       // po 50 min práce v kuse připomene přestávku
    var zvoneni: [String] = []      // časy zvonění "HH:MM" – 2 min předtím se protáhne
    var language = "auto"          // jazyk nabídky: auto, cs, en, de, sk, pl
    var welcomed = false            // úvodní okno už se ukázalo

    init() {}

    enum CodingKeys: String, CodingKey {
        case size, walkSpeed, gravity, claudeWatch, eyeTracking, windowPlatforms, mischief, dockWidth, bedX, showInFullscreen, autostart, bedDX, bedDY, pausedUntil, pausedForever, hideOnExternalMain, breakReminder, zvoneni, language, welcomed
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 80
        walkSpeed = try c.decodeIfPresent(Double.self, forKey: .walkSpeed) ?? 1
        gravity = try c.decodeIfPresent(Double.self, forKey: .gravity) ?? 1
        claudeWatch = try c.decodeIfPresent(Bool.self, forKey: .claudeWatch) ?? true
        eyeTracking = try c.decodeIfPresent(Bool.self, forKey: .eyeTracking) ?? true
        windowPlatforms = try c.decodeIfPresent(Bool.self, forKey: .windowPlatforms) ?? true
        mischief = try c.decodeIfPresent(Bool.self, forKey: .mischief) ?? true
        dockWidth = try c.decodeIfPresent(Double.self, forKey: .dockWidth) ?? 0
        bedX = try c.decodeIfPresent(Double.self, forKey: .bedX) ?? 0
        showInFullscreen = try c.decodeIfPresent(Bool.self, forKey: .showInFullscreen) ?? false
        autostart = try c.decodeIfPresent(Bool.self, forKey: .autostart) ?? false
        bedDX = try c.decodeIfPresent(Double.self, forKey: .bedDX)
        bedDY = try c.decodeIfPresent(Double.self, forKey: .bedDY)
        pausedUntil = try c.decodeIfPresent(Double.self, forKey: .pausedUntil)
        pausedForever = try c.decodeIfPresent(Bool.self, forKey: .pausedForever) ?? false
        hideOnExternalMain = try c.decodeIfPresent(Bool.self, forKey: .hideOnExternalMain) ?? true
        breakReminder = try c.decodeIfPresent(Bool.self, forKey: .breakReminder) ?? false
        zvoneni = try c.decodeIfPresent([String].self, forKey: .zvoneni) ?? []
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "auto"
        welcomed = try c.decodeIfPresent(Bool.self, forKey: .welcomed) ?? false
        size = min(200, max(48, size))
        walkSpeed = min(3, max(0.3, walkSpeed))
        gravity = min(3, max(0.3, gravity))
    }

    static var dir: String { NSHomeDirectory() + "/.jezevcik" }
    static var path: String { dir + "/jezevcik.json" }

    static func load() -> Config {
        guard let data = FileManager.default.contents(atPath: path),
              let cfg = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return cfg
    }

    func save() {
        try? FileManager.default.createDirectory(atPath: Config.dir, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) {
            try? data.write(to: URL(fileURLWithPath: Config.path))
        }
    }
}
