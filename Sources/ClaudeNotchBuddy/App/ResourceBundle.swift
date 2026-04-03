import Foundation

/// SPM의 Bundle.module은 .app 번들 패키징 시 경로를 못 찾는 문제가 있다.
/// Contents/Resources/ 하위도 탐색하는 안전한 래퍼.
enum ResourceBundle {
    static let bundle: Bundle = {
        let bundleName = "ClaudeNotchBuddy_ClaudeNotchBuddy"

        // 1) SPM 기본: Bundle.main/{bundleName}.bundle
        let mainPath = Bundle.main.bundleURL
            .appendingPathComponent("\(bundleName).bundle")
        if let b = Bundle(url: mainPath) { return b }

        // 2) .app 패키징: Contents/Resources/{bundleName}.bundle
        let resourcesPath = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/\(bundleName).bundle")
        if let b = Bundle(url: resourcesPath) { return b }

        // 3) 실행 파일 옆: ../Resources/{bundleName}.bundle
        let execPath = Bundle.main.executableURL?
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/\(bundleName).bundle")
        if let execPath, let b = Bundle(url: execPath) { return b }

        // 4) 빌드 디렉토리 (개발 시)
        #if DEBUG
        let debugPath = Bundle.main.bundleURL
            .appendingPathComponent("\(bundleName).bundle")
        if let b = Bundle(url: debugPath) { return b }
        #endif

        // 5) 최후 수단: Bundle.module (SPM auto-generated)
        return Bundle.module
    }()
}
