import AppKit

/// 터미널 앱을 포커스하는 유틸리티.
enum TerminalFocuser {

    private static let terminalBundleIDs = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "dev.zed.Zed",
        "com.jetbrains.intellij",
        "com.anthropic.claudefordesktop",  // Claude Desktop
        "com.cmuxterm.app",                // cmux
    ]

    /// TerminalApp으로 포커스한다.
    @discardableResult
    static func focus(app: TerminalApp) -> Bool {
        switch app {
        case .tmux, .unknown:
            return focus()
        default:
            if let bundleId = app.bundleId {
                return focus(bundleId: bundleId)
            }
            return focus()
        }
    }

    /// 특정 번들ID의 앱을 포커스한다.
    @discardableResult
    static func focus(bundleId: String) -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.bundleIdentifier == bundleId }) {
            return activate(app)
        }
        // 번들ID로 못 찾으면 일반 포커스 폴백
        return focus()
    }

    /// 실행 중인 터미널 앱을 포커스한다. 성공 시 true.
    @discardableResult
    static func focus() -> Bool {
        let apps = NSWorkspace.shared.runningApplications

        for bundleID in terminalBundleIDs {
            if let app = apps.first(where: { $0.bundleIdentifier == bundleID }) {
                return activate(app)
            }
        }

        // 터미널이 실행 중이 아니면 Terminal.app 열기
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(terminalURL)
        return true
    }

    // MARK: - Private

    private static func activate(_ app: NSRunningApplication) -> Bool {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
        return true
    }
}
