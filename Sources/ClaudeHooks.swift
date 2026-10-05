import Foundation

/// Propojení s Claude Code přímo z aplikace (pro uživatele bez skriptů z projektu).
/// Háček zapisuje do ~/.jezevcik/state, co Claude Code dělá; Julie to čte (Watch.swift).
enum ClaudeHooks {
    static var claudeDir: String { NSHomeDirectory() + "/.claude" }
    static var settingsPath: String { claudeDir + "/settings.json" }
    static var hookPath: String { Config.dir + "/hook.sh" }
    static var claudeExists: Bool { FileManager.default.fileExists(atPath: claudeDir) }

    static let events: [(String, String)] = [("UserPromptSubmit", "prompt"), ("PreToolUse", "pre"),
                                             ("Notification", "notify"), ("Stop", "stop")]

    static let script = #"""
#!/bin/sh
# Julie: zapíše, co Claude Code zrovna dělá, do ~/.jezevcik/state (čte to Julie).
ev="$1"
in=$(cat)
tool=$(printf '%s' "$in" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
case "$ev" in
  prompt) tok=think ;;
  notify) tok=notify ;;
  stop) tok=done ;;
  pre)
    case "$tool" in
      Bash) tok=bash ;;
      Read|Glob|Grep|LS) tok=read ;;
      Edit|Write|MultiEdit|NotebookEdit) tok=edit ;;
      WebFetch|WebSearch) tok=web ;;
      Task|Agent) tok=task ;;
      mcp__*) tok=web ;;
      *) tok=think ;;
    esac ;;
  *) exit 0 ;;
esac
mkdir -p "$HOME/.jezevcik"
printf '%s %s\n' "$tok" "$(date +%s)" > "$HOME/.jezevcik/state"
exit 0
"""#

    private static func load() -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: settingsPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    private static func save(_ obj: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: settingsPath))) != nil
    }

    private static func isOurs(_ group: Any) -> Bool {
        guard let g = group as? [String: Any], let hooks = g["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { (($0["command"] as? String) ?? "").contains("jezevcik/hook.sh") }
    }

    static var installed: Bool {
        guard let hooks = load()["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { ($0 as? [Any])?.contains(where: isOurs) ?? false }
    }

    static func install() -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: Config.dir, withIntermediateDirectories: true)
        guard (try? script.write(toFile: hookPath, atomically: true, encoding: .utf8)) != nil else { return false }
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
        if fm.fileExists(atPath: settingsPath) {
            let backup = settingsPath + ".julie-zaloha"
            try? fm.removeItem(atPath: backup)
            try? fm.copyItem(atPath: settingsPath, toPath: backup)
        }
        var obj = load()
        var hooks = obj["hooks"] as? [String: Any] ?? [:]
        for (event, arg) in events {
            var list = (hooks[event] as? [Any] ?? []).filter { !isOurs($0) }
            list.append(["matcher": "", "hooks": [["type": "command", "command": hookPath + " " + arg]]])
            hooks[event] = list
        }
        obj["hooks"] = hooks
        return save(obj)
    }

    static func uninstall() -> Bool {
        var obj = load()
        guard var hooks = obj["hooks"] as? [String: Any] else { return true }
        for key in hooks.keys {
            let list = (hooks[key] as? [Any] ?? []).filter { !isOurs($0) }
            if list.isEmpty { hooks.removeValue(forKey: key) } else { hooks[key] = list }
        }
        if hooks.isEmpty { obj.removeValue(forKey: "hooks") } else { obj["hooks"] = hooks }
        return save(obj)
    }
}
