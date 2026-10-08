# Julie – pixelový jezevčík na ploše (macOS)

**[English](README.md)**

![Julie](docs/julie.png)

Desktopový mazlíček podle Clawda, ale jezevčík – Karlova fenka Julie. Swift + AppKit, bez Xcode
(stačí Command Line Tools). Julie nemluví, nemá bubliny. Nabídka je v pěti jazycích
(čeština, angličtina, němčina, slovenština, polština; podle systému, přepnout v Nastavení).

**[Stáhnout Julii pro Mac (DMG, 0,7 MB)](https://github.com/hlaska18/Julie/releases/latest/download/Julie.dmg)**
· [web](https://hlaska18.github.io/Julie/cs/) · [všechna vydání](https://github.com/hlaska18/Julie/releases)

![Julie jde po Docku, čuchá, štěká, sedne si a protáhne se](docs/ukazky/chuze.gif)

## Instalace (pro ostatní)
1. Stáhni **[Julie.dmg](https://github.com/hlaska18/Julie/releases/latest/download/Julie.dmg)**, otevři ho a přetáhni **Julie** do **Aplikací**.
2. Otevři Julii. Aplikace není notarizovaná u Applu, macOS proto napíše, že nemůže ověřit vývojáře:
   **Nastavení systému → Soukromí a zabezpečení** → dole **Přesto otevřít**
   (nebo v Terminálu `xattr -dr com.apple.quarantine /Applications/Julie.app`).
3. Úvodní okno ukáže ovládání a nabídne spouštění po přihlášení.

Vyžaduje macOS 12+, Apple Silicon i Intel. Vydání: `./release.sh 1.0.2` → `dist/Julie.dmg` a `dist/Julie.zip`
(univerzální aplikace; před zabalením proběhne samotest; disk v DMG má ikonu Julie v krabici z
`art/dmg_ikona.png`, kreslí ji `art/dmg_ikona.py`). Soubory mají **stálé názvy**, takže odkazy
`releases/latest/download/Julie.dmg` na webu i v README se nemění. Při novém vydání na webu
(`docs/index.html`, `docs/cs/index.html`) přepiš jen číslo verze (text, `softwareVersion`) a SHA-256,
který `release.sh` vypíše na konci.
Soukromí: bez sítě, nic nesbírá
(podrobně v anglickém README).

## Sestavení a spuštění
    ./build.sh
    open ~/Applications/Julie.app

`build.sh` sestaví aplikaci bokem do `build/`, funkční verzi nahradí až po úspěšném překladu
(předchozí zůstane jako `build/Julie-predchozi.app`) a nainstaluje Julie.app i Pelíšek.app do
`~/Applications` (Plocha se synchronizuje přes iCloud, ten by aplikaci mohl odsunout do cloudu).
Řezání obrázků (`art/*.py`) a ikona Pelíšku potřebují Pillow (`pip3 install pillow`).

Kontrola bez obrazovky: `~/Applications/Julie.app/Contents/MacOS/Julie --test` (samotest všech
důležitých chování, vrací 0 = vše OK), dále `--sim pad|padak|pamlsek|pelisek|veverka|dest|micek`
a `--nora soubor.png` (filmový pás nory). `--mereni [od hodiny] [hodin]` nasimuluje den bez člověka
(výchozí 8:00, 8 h) a vypíše, jak často a jak hned za sebou Julie co dělá – podle toho se ladí četnosti.

Nastavení je v `~/.jezevcik/jezevcik.json`, deník událostí v `~/.jezevcik/udalosti.log`.

## Web
Statická stránka v `docs/` pro GitHub Pages (Settings → Pages → Deploy from a branch → `main` / `/docs`),
adresa https://hlaska18.github.io/Julie/ (anglicky) a `/cs/` (česky). Bez sestavování, bez cizích
serverů: písmo Pixelify Sans (OFL) je přibalené v `docs/fonts/`. Barvy: paleta Minty Fresh z coolors.co,
tlačítko a okna podle prvků z Uiverse.io (MIT, autoři v patičce).

- `python3 tools/ukazky.py` natočí GIFy do `docs/ukazky/` ze skutečné aplikace (`Julie --ukazka <scéna>`,
  vrstvy kreslí CARenderer mimo obrazovku, scéna běží v reálném čase). Po změně chování nebo vzhledu
  Julie spustit znovu.
- `python3 tools/web_obrazky.py` udělá pózy, ikonu a náhledy pro sdílení (`docs/img/og.png`, `og-cs.png`).

## Vzhled
Podle Karlova obrázku `art/styl_julie.png` (hrubé pixely, bez obrysu). Pózy nakreslil
Higgsfield (gpt_image_2_5, 1k, průhledně) s tímto obrázkem jako předlohou, listy jsou v `art/listy/`.
`art/rozrez.py` je rozřeže na snímky v pixelové mřížce do `art/sprity/` (stojící Julie 44 px,
protažená o 15 % jako na předloze, společná paleta; veverka, sušenky a pelíšek mají vlastní paletu).
Hrabání (`hrabe0–3`) skládá `art/hrabani_tlapky.py` z jednoho snímku a ručně kreslených tlapek
(Higgsfield kreslil tlapky skoro stejně). Starší detailní sada je v `art/detailni/`.
Novou pózu: vygeneruj list se stojící Julií jako 1. snímkem, přidej ho do `LISTY` a spusť skript.

## Co umí
Julie nemluví a nemá bubliny; štěknutí ukazují pixelové zvukové vlny. Chodí jen po Docku
a nepřejde jeho hranu. Leze po hranách oken a jezdí s nimi. Po chycení myší visí za kůži;
po puštění dopadne **bez odrážení** a otřepe se. Puštěná vysoko (nad polovinou obrazovky,
u obrazovky na výšku nad třetinou) se snese na **padáčku**. Čuchá, drbe se, štěká, spí,
hrabe noru (očichá, hrabe – tlapky se střídají, hlína letí dozadu na kupku –, zanoří se hlavou
napřed a vyleze jinde přímo z díry). Pelíšek vedle Docku (spí v klubíčku), pamlsky, míček (aport),
veverka (sprint s vyplazeným jazykem), balónky, hlazení, denní režim.

Ovládání (je i v menu 🦴 → Jak na Julii):
- **pohladit**: přejížděj kurzorem po Julii sem a tam → lehne si, vyletí srdíčka
- **pamlsek**: ⌃⌥P → pamlsek u kurzoru, Julie si pro něj přijde; vysoko panáčkuje (po 3 pokusech
  čeká vsedě); další ⌃⌥P ho pustí. Menu 🦴 → Dát pamlsek → spadne na Dock
- **míček**: ⌃⌥M nebo ho chyť myší a hoď → úklona k hraní, doběhne, přinese ho pod kurzor
- **zvednout**: chyť ji myší a táhni, pak pusť
- **pelíšek**: klik = spát / vstávat; tažením ho posuneš (Nastavení → Pelíšek zpět vedle Docku);
  když se nevejde do pruhu Docku (obří velikost), není; před ulehnutím ho očichá a otočí se
- **kliknout na Julii**: štěkne
- **uspat (schovat)**: menu 🦴 → Uspat → na hodinu / do zítřka / dokud ji zase nezapnu
  (platí i po restartu Macu; probudí se v menu 🦴 → Probudit Julii)

Denní režim: v noci (22–7) a večer víc spí a chodí do pelíšku, ráno je čilejší.
Spouští se po přihlášení (`~/Library/LaunchAgents/cz.karelhlas.julie.plist`; nový uživatel volí v úvodním okně, vypnout v Nastavení).
Volitelně (Nastavení): připomenutí přestávky po 50 minutách práce v kuse (přiběhne pod kurzor
a štěkne); zvonění: do json `"zvoneni": ["8:45", "9:40"]` – 2 minuty před zvoněním se protáhne.

## Co Julie udělá v různých situacích
| Situace | Julie |
|---|---|
| aplikace na celé obrazovce | schová se (přepínač „Ukazovat i přes celou obrazovku“) |
| zrcadlení obrazovky (projektor, AirPlay) | schová se |
| hlavní obrazovka je externí (projektor) a MacBook je zapnutý | schová se (přepínač v Nastavení) |
| sdílení obrazovky v Teams | nepozná se → menu 🦴 → Uspat na hodinu |
| Dock vlevo/vpravo, automaticky skrývaný nebo na jiném monitoru | schová se (nemá kde chodit) |
| displej spí, Mac je zamčený | stojí (nic nepočítá) |
| odpojení / připojení monitoru | přepočítá obrazovku a Dock, postaví se na Dock |
| druhý monitor | chodí jen po hlavním (s Dockem) |
| Stage Manager | chodí po Docku normálně |

## Spotřeba
Počet snímků podle toho, co dělá: hod, pád a hry 60/s, chůze 30/s, klid 10/s, spánek 6/s;
obrázek se kreslí znovu jen při změně; okna ostatních aplikací čte jen při lezení; schovaná
skoro nic nedělá. Změřeno 5. 10. 2026: dřív trvale ~7,5 % CPU, teď ~1,5 %. WindowServer
(skládání obrazu) byl s Julií i bez ní stejný (~44 % kvůli jiným aplikacím).

## Claude Code
Propojení: 🦴 → Nastavení → Propojit s Claude Code (nebo `tools/claude-watch-on.sh`); přidá háčky do
`~/.claude/settings.json` (uloží zálohu), odpojit jde tamtéž (nebo `claude-watch-off.sh`). Bez bublin: sedne si (přemýšlí), hrabe (příkaz, úprava kódu), čuchá (čtení),
rozhlíží se (web, agent), štěká (Claude čeká na tebe – opakovaně, dokud čeká), při „hotovo“
přinese míček (když leží na Docku), jinak radostně vyskočí.

## Zpětná vazba
Co vypadá nepřirozeně nebo otravuje, si Karel zapisuje do `poznamky.txt`; opravuje se v dávkách.

## Licence
Kód: [MIT](LICENSE). Obrázky (pixel art Julie, pelíšek, veverka, pamlsky): [CC BY-NC 4.0](art/LICENSE) –
sdílet a upravovat smí každý, ale ne komerčně a s uvedením autora.
