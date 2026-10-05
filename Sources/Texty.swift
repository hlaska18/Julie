import Foundation

/// Texty aplikace v několika jazycích. Julie sama nemluví – tohle jsou jen nabídka a úvodní okno.
/// Jazyk: nastavení `language` ("auto" = podle systému), jinak cs/en/de/sk/pl; neznámý → angličtina.
enum Texty {
    static let jazyky: [(kod: String, nazev: String)] = [
        ("cs", "Čeština"), ("en", "English"), ("de", "Deutsch"), ("sk", "Slovenčina"), ("pl", "Polski")]

    static var aktivni = "cs"

    static func nastav(_ volba: String) {
        if volba != "auto", tabulka[volba] != nil { aktivni = volba; return }
        for pref in Locale.preferredLanguages {
            let k = String(pref.prefix(2))
            if tabulka[k] != nil { aktivni = k; return }
        }
        aktivni = "en"
    }

    /// Přeložený text; `{0}` se nahradí argumentem.
    static func t(_ klic: String, _ arg: String = "") -> String {
        let s = tabulka[aktivni]?[klic] ?? tabulka["en"]?[klic] ?? klic
        return s.replacingOccurrences(of: "{0}", with: arg)
    }

    static let tabulka: [String: [String: String]] = [
        "cs": [
            "treat": "Dát pamlsek", "ball": "Hodit míček", "bed": "Do pelíšku / vzbudit", "call": "Zavolat Julii",
            "sleep": "Uspat (schovat)", "sleepHour": "na hodinu", "sleepTomorrow": "do zítřka", "sleepForever": "dokud ji zase nezapnu",
            "wakeForever": "Probudit Julii (uspaná, dokud ji nezapneš)", "wakeUntil": "Probudit Julii (uspaná do {0})",
            "surprise": "Překvapení", "balloons": "Balónky", "squirrel": "Veverka", "treatRain": "Déšť pamlsků", "burrow": "Nora",
            "settings": "Nastavení", "size": "Velikost", "small": "Malá", "medium": "Střední", "large": "Velká", "huge": "Obří",
            "speed": "Rychlost chůze", "slow": "Pomalá", "normal": "Normální", "fast": "Rychlá", "language": "Jazyk", "auto": "Podle systému",
            "autostart": "Spouštět po přihlášení", "claude": "Reagovat na Claude Code", "turn": "Otáčet se za kurzorem",
            "climb": "Lézt po oknech", "mischief": "Darebáctví (nora, překvapení)", "fullscreen": "Ukazovat i přes celou obrazovku",
            "projector": "Schovat, když je hlavní obrazovka projektor", "break": "Připomenout přestávku po 50 min práce",
            "bedReset": "Pelíšek zpět vedle Docku", "dockExact": "Dock změřen přesně ✓", "dockMeasure": "Přesně změřit Dock (Zpřístupnění)…",
            "claudeConnect": "Propojit s Claude Code…", "claudeDisconnect": "Odpojit od Claude Code",
            "help": "Jak na Julii", "quit": "Konec",
            "h1": "Pamlsek u kurzoru: ⌃⌥P (znovu = pustit)", "h2": "Míček: ⌃⌥M, nebo ho chyť myší a hoď",
            "h3": "Pohladit: přejížděj kurzorem po Julii", "h4": "Zvednout: chyť ji myší a pusť",
            "h5": "Pelíšek: klik = spát / vstávat, tažením ho posuneš", "h6": "Pustíš-li ji vysoko, snese se na padáčku",
            "welcomeTitle": "Julie – pixelový jezevčík na tvém Docku",
            "welcomeText": "Julie chodí po Docku, čuchá, hrabe nory a spí v pelíšku vedle Docku.\n\n• Pohladit: přejížděj kurzorem po Julii\n• Zvednout a hodit: chyť ji myší\n• Pamlsek: ⌃⌥P, míček: ⌃⌥M\n• Všechno ostatní najdeš pod ikonou 🦴 v horní liště.\n\nNa celé obrazovce a při zrcadlení na projektor se schová.",
            "welcomeAutostart": "Spouštět Julii po přihlášení", "ok": "Jdeme na to!",
            "claudeTitle": "Propojit Julii s Claude Code?",
            "claudeText": "Julie bude reagovat na to, co Claude Code dělá: sedne si, když přemýšlí, hrabe při příkazech, štěká, když na tebe čeká, a vyskočí, když je hotovo.\n\nDo ~/.claude/settings.json se přidají háčky (původní soubor se zazálohuje). Odpojit jde kdykoli v Nastavení.",
            "claudeYes": "Propojit", "cancel": "Zrušit",
            "claudeDone": "Hotovo. Spusť Claude Code znovu, ať si háčky načte.", "claudeRemoved": "Háčky Julie jsou z Claude Code odebrané.",
            "claudeMissing": "Claude Code tu nenašla (chybí složka ~/.claude).",
        ],
        "en": [
            "treat": "Give a treat", "ball": "Throw the ball", "bed": "To bed / wake up", "call": "Call Julie",
            "sleep": "Put to sleep (hide)", "sleepHour": "for an hour", "sleepTomorrow": "until tomorrow", "sleepForever": "until I turn her on again",
            "wakeForever": "Wake Julie up (asleep until you turn her on)", "wakeUntil": "Wake Julie up (asleep until {0})",
            "surprise": "Surprise", "balloons": "Balloons", "squirrel": "Squirrel", "treatRain": "Treat rain", "burrow": "Burrow",
            "settings": "Settings", "size": "Size", "small": "Small", "medium": "Medium", "large": "Large", "huge": "Huge",
            "speed": "Walking speed", "slow": "Slow", "normal": "Normal", "fast": "Fast", "language": "Language", "auto": "System default",
            "autostart": "Start at login", "claude": "React to Claude Code", "turn": "Turn towards the cursor",
            "climb": "Climb windows", "mischief": "Mischief (burrows, surprises)", "fullscreen": "Show over full-screen apps",
            "projector": "Hide when the main display is a projector", "break": "Remind me to take a break after 50 min",
            "bedReset": "Put the bed back next to the Dock", "dockExact": "Dock measured exactly ✓", "dockMeasure": "Measure the Dock exactly (Accessibility)…",
            "claudeConnect": "Connect to Claude Code…", "claudeDisconnect": "Disconnect from Claude Code",
            "help": "How to play with Julie", "quit": "Quit",
            "h1": "Treat at the cursor: ⌃⌥P (again = drop it)", "h2": "Ball: ⌃⌥M, or grab it with the mouse and throw",
            "h3": "Pet her: move the cursor back and forth over Julie", "h4": "Pick her up: grab her with the mouse and let go",
            "h5": "Bed: click = sleep / wake up, drag to move it", "h6": "Drop her from high up and she floats down on a parachute",
            "welcomeTitle": "Julie – a pixel dachshund on your Dock",
            "welcomeText": "Julie walks along your Dock, sniffs around, digs burrows and sleeps in her bed next to the Dock.\n\n• Pet her: move the cursor back and forth over Julie\n• Pick her up and throw her: grab her with the mouse\n• Treat: ⌃⌥P, ball: ⌃⌥M\n• Everything else is under the 🦴 icon in the menu bar.\n\nShe hides in full-screen apps and when the screen is mirrored to a projector.",
            "welcomeAutostart": "Start Julie at login", "ok": "Let's go!",
            "claudeTitle": "Connect Julie to Claude Code?",
            "claudeText": "Julie will react to what Claude Code is doing: she sits while it thinks, digs while it runs commands, barks when it is waiting for you and jumps when it is done.\n\nHooks will be added to ~/.claude/settings.json (the original file is backed up). You can disconnect any time in Settings.",
            "claudeYes": "Connect", "cancel": "Cancel",
            "claudeDone": "Done. Restart Claude Code so it loads the hooks.", "claudeRemoved": "Julie's hooks were removed from Claude Code.",
            "claudeMissing": "Claude Code was not found (no ~/.claude folder).",
        ],
        "de": [
            "treat": "Leckerli geben", "ball": "Ball werfen", "bed": "Ins Körbchen / aufwecken", "call": "Julie rufen",
            "sleep": "Schlafen legen (ausblenden)", "sleepHour": "für eine Stunde", "sleepTomorrow": "bis morgen", "sleepForever": "bis ich sie wieder einschalte",
            "wakeForever": "Julie aufwecken (schläft, bis du sie einschaltest)", "wakeUntil": "Julie aufwecken (schläft bis {0})",
            "surprise": "Überraschung", "balloons": "Luftballons", "squirrel": "Eichhörnchen", "treatRain": "Leckerli-Regen", "burrow": "Bau graben",
            "settings": "Einstellungen", "size": "Größe", "small": "Klein", "medium": "Mittel", "large": "Groß", "huge": "Riesig",
            "speed": "Gehgeschwindigkeit", "slow": "Langsam", "normal": "Normal", "fast": "Schnell", "language": "Sprache", "auto": "Systemsprache",
            "autostart": "Bei der Anmeldung starten", "claude": "Auf Claude Code reagieren", "turn": "Zum Mauszeiger drehen",
            "climb": "Auf Fenster klettern", "mischief": "Unfug (Bau, Überraschungen)", "fullscreen": "Auch über Vollbild-Apps zeigen",
            "projector": "Ausblenden, wenn der Hauptbildschirm ein Beamer ist", "break": "Nach 50 Min Arbeit an eine Pause erinnern",
            "bedReset": "Körbchen zurück neben das Dock", "dockExact": "Dock genau vermessen ✓", "dockMeasure": "Dock genau vermessen (Bedienungshilfen)…",
            "claudeConnect": "Mit Claude Code verbinden…", "claudeDisconnect": "Von Claude Code trennen",
            "help": "So spielst du mit Julie", "quit": "Beenden",
            "h1": "Leckerli am Mauszeiger: ⌃⌥P (nochmal = fallen lassen)", "h2": "Ball: ⌃⌥M, oder mit der Maus greifen und werfen",
            "h3": "Streicheln: den Zeiger über Julie hin und her bewegen", "h4": "Hochheben: mit der Maus greifen und loslassen",
            "h5": "Körbchen: Klick = schlafen / aufstehen, ziehen = verschieben", "h6": "Lässt du sie hoch oben los, schwebt sie am Fallschirm herab",
            "welcomeTitle": "Julie – ein Pixel-Dackel auf deinem Dock",
            "welcomeText": "Julie läuft auf deinem Dock herum, schnüffelt, gräbt Baue und schläft in ihrem Körbchen neben dem Dock.\n\n• Streicheln: den Zeiger über Julie hin und her bewegen\n• Hochheben und werfen: mit der Maus greifen\n• Leckerli: ⌃⌥P, Ball: ⌃⌥M\n• Alles andere findest du unter dem 🦴-Symbol in der Menüleiste.\n\nIn Vollbild-Apps und bei Bildschirmspiegelung auf einen Beamer versteckt sie sich.",
            "welcomeAutostart": "Julie bei der Anmeldung starten", "ok": "Los geht's!",
            "claudeTitle": "Julie mit Claude Code verbinden?",
            "claudeText": "Julie reagiert darauf, was Claude Code tut: Sie sitzt, während es nachdenkt, gräbt bei Befehlen, bellt, wenn es auf dich wartet, und springt, wenn es fertig ist.\n\nIn ~/.claude/settings.json werden Hooks eingetragen (die Originaldatei wird gesichert). Trennen geht jederzeit in den Einstellungen.",
            "claudeYes": "Verbinden", "cancel": "Abbrechen",
            "claudeDone": "Fertig. Starte Claude Code neu, damit es die Hooks lädt.", "claudeRemoved": "Julies Hooks wurden aus Claude Code entfernt.",
            "claudeMissing": "Claude Code wurde nicht gefunden (Ordner ~/.claude fehlt).",
        ],
        "sk": [
            "treat": "Dať maškrtu", "ball": "Hodiť loptičku", "bed": "Do pelieška / zobudiť", "call": "Zavolať Julie",
            "sleep": "Uspať (skryť)", "sleepHour": "na hodinu", "sleepTomorrow": "do zajtra", "sleepForever": "kým ju znova nezapnem",
            "wakeForever": "Zobudiť Julie (spí, kým ju nezapneš)", "wakeUntil": "Zobudiť Julie (spí do {0})",
            "surprise": "Prekvapenie", "balloons": "Balóny", "squirrel": "Veverička", "treatRain": "Dážď maškŕt", "burrow": "Nora",
            "settings": "Nastavenia", "size": "Veľkosť", "small": "Malá", "medium": "Stredná", "large": "Veľká", "huge": "Obrovská",
            "speed": "Rýchlosť chôdze", "slow": "Pomalá", "normal": "Normálna", "fast": "Rýchla", "language": "Jazyk", "auto": "Podľa systému",
            "autostart": "Spúšťať po prihlásení", "claude": "Reagovať na Claude Code", "turn": "Otáčať sa za kurzorom",
            "climb": "Liezť po oknách", "mischief": "Šibalstvo (nora, prekvapenia)", "fullscreen": "Ukazovať aj cez celú obrazovku",
            "projector": "Skryť, keď je hlavná obrazovka projektor", "break": "Pripomenúť prestávku po 50 min práce",
            "bedReset": "Pelieško späť vedľa Docku", "dockExact": "Dock zmeraný presne ✓", "dockMeasure": "Presne zmerať Dock (Prístupnosť)…",
            "claudeConnect": "Prepojiť s Claude Code…", "claudeDisconnect": "Odpojiť od Claude Code",
            "help": "Ako na Julie", "quit": "Koniec",
            "h1": "Maškrta pri kurzore: ⌃⌥P (znova = pustiť)", "h2": "Loptička: ⌃⌥M, alebo ju chyť myšou a hoď",
            "h3": "Pohladkať: prechádzaj kurzorom po Julie sem a tam", "h4": "Zdvihnúť: chyť ju myšou a pusť",
            "h5": "Pelieško: klik = spať / vstávať, ťahaním ho posunieš", "h6": "Keď ju pustíš vysoko, znesie sa na padáku",
            "welcomeTitle": "Julie – pixelový jazvečík na tvojom Docku",
            "welcomeText": "Julie chodí po Docku, ňuchá, hrabe nory a spí v peliešku vedľa Docku.\n\n• Pohladkať: prechádzaj kurzorom po Julie\n• Zdvihnúť a hodiť: chyť ju myšou\n• Maškrta: ⌃⌥P, loptička: ⌃⌥M\n• Všetko ostatné nájdeš pod ikonou 🦴 v hornej lište.\n\nNa celej obrazovke a pri zrkadlení na projektor sa skryje.",
            "welcomeAutostart": "Spúšťať Julie po prihlásení", "ok": "Ideme na to!",
            "claudeTitle": "Prepojiť Julie s Claude Code?",
            "claudeText": "Julie bude reagovať na to, čo Claude Code robí: sadne si, keď premýšľa, hrabe pri príkazoch, šteká, keď na teba čaká, a vyskočí, keď je hotovo.\n\nDo ~/.claude/settings.json sa pridajú háčiky (pôvodný súbor sa zálohuje). Odpojiť sa dá kedykoľvek v Nastaveniach.",
            "claudeYes": "Prepojiť", "cancel": "Zrušiť",
            "claudeDone": "Hotovo. Spusti Claude Code znova, nech si háčiky načíta.", "claudeRemoved": "Háčiky Julie sú z Claude Code odstránené.",
            "claudeMissing": "Claude Code sa nenašiel (chýba priečinok ~/.claude).",
        ],
        "pl": [
            "treat": "Daj smakołyk", "ball": "Rzuć piłkę", "bed": "Do legowiska / obudź", "call": "Zawołaj Julię",
            "sleep": "Uśpij (ukryj)", "sleepHour": "na godzinę", "sleepTomorrow": "do jutra", "sleepForever": "aż ją znów włączę",
            "wakeForever": "Obudź Julię (śpi, aż ją włączysz)", "wakeUntil": "Obudź Julię (śpi do {0})",
            "surprise": "Niespodzianka", "balloons": "Baloniki", "squirrel": "Wiewiórka", "treatRain": "Deszcz smakołyków", "burrow": "Nora",
            "settings": "Ustawienia", "size": "Rozmiar", "small": "Mała", "medium": "Średnia", "large": "Duża", "huge": "Ogromna",
            "speed": "Prędkość chodzenia", "slow": "Wolna", "normal": "Normalna", "fast": "Szybka", "language": "Język", "auto": "Jak w systemie",
            "autostart": "Uruchamiaj po zalogowaniu", "claude": "Reaguj na Claude Code", "turn": "Odwracaj się do kursora",
            "climb": "Wspinaj się po oknach", "mischief": "Psoty (nora, niespodzianki)", "fullscreen": "Pokazuj też nad aplikacjami pełnoekranowymi",
            "projector": "Ukryj, gdy głównym ekranem jest projektor", "break": "Przypomnij o przerwie po 50 min pracy",
            "bedReset": "Legowisko z powrotem obok Docka", "dockExact": "Dock zmierzony dokładnie ✓", "dockMeasure": "Zmierz Dock dokładnie (Dostępność)…",
            "claudeConnect": "Połącz z Claude Code…", "claudeDisconnect": "Odłącz od Claude Code",
            "help": "Jak bawić się z Julią", "quit": "Zakończ",
            "h1": "Smakołyk przy kursorze: ⌃⌥P (ponownie = upuść)", "h2": "Piłka: ⌃⌥M albo złap ją myszą i rzuć",
            "h3": "Pogłaskaj: przesuwaj kursor nad Julią tam i z powrotem", "h4": "Podnieś: złap ją myszą i puść",
            "h5": "Legowisko: klik = spać / wstać, przeciągnij, by przesunąć", "h6": "Puszczona wysoko sfrunie na spadochronie",
            "welcomeTitle": "Julie – pikselowy jamnik na twoim Docku",
            "welcomeText": "Julie chodzi po Docku, węszy, kopie nory i śpi w legowisku obok Docka.\n\n• Pogłaskaj: przesuwaj kursor nad Julią\n• Podnieś i rzuć: złap ją myszą\n• Smakołyk: ⌃⌥P, piłka: ⌃⌥M\n• Wszystko inne znajdziesz pod ikoną 🦴 na pasku menu.\n\nChowa się w aplikacjach pełnoekranowych i przy dublowaniu ekranu na projektor.",
            "welcomeAutostart": "Uruchamiaj Julię po zalogowaniu", "ok": "Do dzieła!",
            "claudeTitle": "Połączyć Julię z Claude Code?",
            "claudeText": "Julie będzie reagować na to, co robi Claude Code: siada, gdy myśli, kopie przy poleceniach, szczeka, gdy na ciebie czeka, i podskakuje, gdy skończy.\n\nDo ~/.claude/settings.json zostaną dodane hooki (oryginalny plik zostanie zarchiwizowany). Odłączyć można w każdej chwili w Ustawieniach.",
            "claudeYes": "Połącz", "cancel": "Anuluj",
            "claudeDone": "Gotowe. Uruchom ponownie Claude Code, aby wczytał hooki.", "claudeRemoved": "Hooki Julii zostały usunięte z Claude Code.",
            "claudeMissing": "Nie znaleziono Claude Code (brak folderu ~/.claude).",
        ],
    ]
}
