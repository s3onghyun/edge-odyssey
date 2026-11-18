import Testing
@testable import EdgeMotion

// The Settings window (Sources/Settings.swift) changes settings through the same control commands
// as the menu, so each control saves the same UserDefaults key the menu item does.

@Suite struct SettingsWindow {
    @Test func everyControlSavesTheMenusKey() throws {
        let main = try repoFile("Sources/main.swift")
        let control = try ControlCases(main)
        let known = Set(control.keys.keys)
        let window = sentCommands(try repoFile("Sources/Settings.swift"), known: known)
        let menu = sentCommands(between(main, "func menuNeedsUpdate", "// MARK: focus mode") + (try repoFile("Sources/UpdateNotice.swift")), known: known)
        #expect(control.keys.count > 40, "found only \(control.keys.count) control cases: is the parser still reading main.swift?")
        // every setting the menu saves is in the window
        let savedByMenu = menu.filter { !(control.keys[$0] ?? []).isEmpty && $0 != "skip-update" }   // an answer to the update notice
        #expect(savedByMenu.count > 20)
        #expect(savedByMenu.subtracting(window).isEmpty, "missing from the Settings window: \(savedByMenu.subtracting(window).sorted())")
        // each window command saves a key, apart from the ones that save elsewhere
        let elsewhere: Set = ["language", "login", "update-check", "focus-display", "reset-session-goal"]   // setLanguage, SMAppService, actions, openFocusMode
        for c in window.subtracting(elsewhere) { #expect(!(control.keys[c] ?? []).isEmpty, "\(c) saves no setting") }
        let expected = ["focus": "focusMinutes", "rest": "restMinutes", "long-every": "longEvery", "session-goal": "sessionGoal", "timer": "timerSeconds", "mode": "mode",
                        "notify": "notifyAtEnd", "sound": "sound", "volume": "soundVolume", "dial-sound": "dialSound", "autorest": "autoStartBreak",
                        "autorest-after": "autoRestMinutes", "autonext": "autoNextFocus", "style": "style", "pace": "pace",
                        "display": "display", "thickness": "thickness", "last5": "onlyLast5", "seconds": "showSeconds",
                        "background": "focusBackground", "background-folder": "backgroundFolder", "drift": "backgroundDrift",
                        "agent": "agentEnabled", "lotus-enabled": "lotusEnabled", "share-hide": "hideWhenCaptured", "updates": "checkUpdates",
                        "char": "character"]
        for (c, k) in expected {
            #expect(window.contains(c), "the window never sends \(c)")
            #expect(control.keys[c] == [k], "\(c) saves \(control.keys[c] ?? []), not \(k)")
        }
    }
}
