import Foundation

/// Claude Code settings.json에 HTTP 훅을 자동으로 설정한다.
/// 기존 설정을 보존하면서 훅만 추가한다.
enum HookInstaller {

    private static let settingsPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.claude/settings.json"
    }()

    private static let hookURL = "http://localhost:31982/hook"

    private static let hookEvents = [
        "SessionStart", "PreToolUse", "PostToolUse",
        "Notification", "Stop", "SessionEnd"
    ]

    /// 훅이 설정되어 있는지 확인한다.
    static func isInstalled() -> Bool {
        guard let settings = readSettings() else { return false }
        guard let hooks = settings["hooks"] as? [String: Any] else { return false }

        // 하나라도 우리 URL이 있으면 설치됨
        for event in hookEvents {
            if let eventHooks = hooks[event] as? [[String: Any]] {
                for hookGroup in eventHooks {
                    if let hookList = hookGroup["hooks"] as? [[String: Any]] {
                        for hook in hookList {
                            if hook["url"] as? String == hookURL {
                                return true
                            }
                            // command 타입에서 URL 확인
                            if let cmd = hook["command"] as? String, cmd.contains(hookURL) {
                                return true
                            }
                        }
                    }
                }
            }
        }
        return false
    }

    /// 필요 시 훅을 설치한다. true = 새로 설치됨, false = 이미 있음.
    @discardableResult
    static func installIfNeeded() -> Bool {
        if isInstalled() {
            print("[HookInstaller] 훅이 이미 설정되어 있음")
            return false
        }

        // ~/.claude/ 디렉토리 생성
        let claudeDir = (settingsPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(
            atPath: claudeDir,
            withIntermediateDirectories: true
        )

        // 기존 설정 읽기 (없으면 빈 딕셔너리)
        var settings = readSettings() ?? [:]
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // curl 명령으로 훅 이벤트를 HTTP POST로 전달
        let curlCommand = "curl -sf -X POST \(hookURL) -H 'Content-Type: application/json' -d @- --max-time 2 2>/dev/null || true"

        for event in hookEvents {
            var eventList = hooks[event] as? [[String: Any]] ?? []

            let hookEntry: [String: Any] = [
                "hooks": [
                    [
                        "type": "command",
                        "command": curlCommand
                    ]
                ]
            ]

            eventList.append(hookEntry)
            hooks[event] = eventList
        }

        settings["hooks"] = hooks

        // 저장
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: settingsPath))
            print("[HookInstaller] 훅 설정 완료: \(settingsPath)")
            return true
        } catch {
            print("[HookInstaller] 설정 저장 실패: \(error)")
            return false
        }
    }

    /// 훅 설정을 제거한다.
    static func uninstall() {
        guard var settings = readSettings() else { return }
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in hookEvents {
            guard var eventList = hooks[event] as? [[String: Any]] else { continue }

            eventList.removeAll { hookGroup in
                guard let hookList = hookGroup["hooks"] as? [[String: Any]] else { return false }
                return hookList.contains { hook in
                    if let cmd = hook["command"] as? String { return cmd.contains(hookURL) }
                    if let url = hook["url"] as? String { return url == hookURL }
                    return false
                }
            }

            if eventList.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = eventList
            }
        }

        settings["hooks"] = hooks.isEmpty ? nil : hooks

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
            print("[HookInstaller] 훅 제거 완료")
        }
    }

    // MARK: - Private

    private static func readSettings() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: settingsPath) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
