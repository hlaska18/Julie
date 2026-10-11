import Foundation

/// Roční období podle data v Macu. Zvyky skutečné Julie (Karlovy poznámky 10. 10. 2026):
/// na podzim skákala do hromádek listí, v zimě do závějí, že jí koukal jen ocas, na jaře
/// hodně chodila a v létě v poledne odpočívala ve stínu.
/// Na jižní polokouli (podle časového pásma) se období posune o půl roku.
/// Zjednodušeno: tropy, kde žádná zima ani podzim nejsou, se neřeší.
enum Obdobi: Int {
    case jaro, leto, podzim, zima

    static func podle(mesice m: Int, pasmo: TimeZone = .current) -> Obdobi {
        let mesic = jizni(pasmo) ? (m + 5) % 12 + 1 : m
        switch mesic {
        case 3...5: return .jaro
        case 6...8: return .leto
        case 9...11: return .podzim
        default: return .zima
        }
    }

    static func jizni(_ pasmo: TimeZone) -> Bool {
        jizniPasma.contains { pasmo.identifier.hasPrefix($0) }
    }

    /// Časová pásma mírného pásu jižní polokoule (tam je v červenci zima).
    private static let jizniPasma = [
        "Australia/", "Antarctica/", "Pacific/Auckland", "Pacific/Chatham", "America/Argentina/",
        "America/Santiago", "America/Punta_Arenas", "America/Montevideo", "Africa/Johannesburg",
        "Africa/Maseru", "Atlantic/Stanley",
    ]
}
