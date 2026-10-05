import Foundation

/// Sleduje, co dělá Claude Code. Háčky (hooks) zapisují do ~/.jezevcik/state řádek "token epoch".
final class Watch {
    private(set) var token = ""
    private(set) var stamp: TimeInterval = 0
    private(set) var changes = 0          // přibude při každé nové zprávě od háčku
    private var changedAt: TimeInterval = 0
    private var phrase = ""
    private let path = Config.dir + "/state"
    private var lastMod: Date?

    func poll() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let mod = attrs[.modificationDate] as? Date else { return }
        if mod == lastMod { return }
        lastMod = mod
        guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let parts = s.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
        guard let t = parts.first else { return }
        let epoch = parts.count > 1 ? TimeInterval(parts[1]) ?? Date().timeIntervalSince1970 : Date().timeIntervalSince1970
        let tok = String(t)
        if tok != token || epoch != stamp {
            let phrases = Watch.phrases[tok] ?? [tok]
            if tok != token { phrase = phrases.randomElement()! }
            token = tok
            stamp = epoch
            changedAt = Date().timeIntervalSince1970
            changes += 1
        }
    }

    private func limit(_ tok: String) -> TimeInterval {
        switch tok {
        case "done": return 6
        case "notify": return 20
        case "think": return 90
        default: return 45
        }
    }

    /// Aktivní token (nebo nil, když je Claude Code zticha).
    var active: String? {
        guard !token.isEmpty else { return nil }
        let age = Date().timeIntervalSince1970 - stamp
        return age < limit(token) ? token : nil
    }

    var text: String? {
        guard let t = active else { return nil }
        if t == "done" { return "✓ " + phrase }
        return phrase
    }

    static let phrases: [String: [String]] = [
        "think": ["Přemýšlím… 🤔", "Čuchám stopu…", "Hmmm…"],
        "bash": ["Hrabu v nořičce (příkaz)", "Hrabu, hrabu…", "Spouštím příkaz 🕳️"],
        "read": ["Čuch čuch… čtu soubor", "Očichávám kód 👃", "Čtu stopy"],
        "edit": ["Hlodám kód 🦴", "Přepisuju, tiše…", "Píšu kód packama"],
        "web": ["Štěkám na web 🌐", "Hledám na netu…", "Haf, co je na webu?"],
        "task": ["Posílám pomocníka do nory", "Zavolala jsem smečku 🐕", "Delegujeme!"],
        "notify": ["Haf! Potřebuju tě!", "Hej, koukni sem! 🔔", "Čeká se na tebe"],
        "done": ["Hotovo, pamlsek?", "Hotovo! 🌭", "Splněno, páníčku"]
    ]

    /// Jak má Julie na token reagovat pózou.
    static func act(for tok: String) -> Act {
        switch tok {
        case "think": return .sit
        case "bash", "edit": return .scrabble
        case "read": return .sniff
        case "web": return .bark
        case "task": return .look
        case "notify": return .bark
        case "done": return .happy
        default: return .sit
        }
    }
}
