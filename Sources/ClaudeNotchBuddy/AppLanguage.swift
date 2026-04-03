import Foundation

/// 앱 내 표시 언어.
enum AppLanguage: String, CaseIterable {
    case ko = "ko"
    case en = "en"
    case ja = "ja"
    case zh = "zh"

    var displayName: String {
        switch self {
        case .ko: return "한국어"
        case .en: return "English"
        case .ja: return "日本語"
        case .zh: return "中文"
        }
    }

    // MARK: - 저장/로드

    private static let key = "appLanguage"

    static var saved: AppLanguage {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let lang = AppLanguage(rawValue: raw) else { return .ko }
        return lang
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: AppLanguage.key)
    }
}
