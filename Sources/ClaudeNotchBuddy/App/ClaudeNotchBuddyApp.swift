import AppKit

/// 앱의 메인 엔트리포인트.
/// NSApplicationDelegate를 통해 앱 라이프사이클을 관리한다.
@main
struct ClaudeNotchBuddyApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
