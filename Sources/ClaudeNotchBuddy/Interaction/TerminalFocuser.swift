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
                app.activate(options: .activateIgnoringOtherApps)
                return true
            }
        }

        // 터미널이 실행 중이 아니면 Terminal.app 열기
        let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(terminalURL)
        return true
    }
}
