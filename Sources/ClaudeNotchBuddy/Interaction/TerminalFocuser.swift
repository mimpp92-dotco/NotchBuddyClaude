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
        "com.anthropic.claudecode",        // Claude Code Desktop
    ]

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

    /// 특정 폴더명으로 작업 중인 터미널을 찾아 포커스한다.
    /// 정확한 매칭이 안 되면 일반 focus()로 폴백.
    @discardableResult
    static func focus(folderName: String) -> Bool {
        // Claude Code가 실행 중인 프로세스에서 cwd 기반으로 터미널 PID를 추적하기는
        // 어려우므로, 실행 중인 터미널 앱 중 가장 최근 활성화된 것을 포커스.
        // 향후 세션별 PID 추적이 추가되면 여기서 매칭 가능.
        return focus()
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
