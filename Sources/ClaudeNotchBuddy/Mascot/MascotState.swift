import Foundation

/// 마스코트의 현재 상태를 나타내는 enum.
enum MascotState: String, CaseIterable, Sendable {
    case idle          // 유휴 — 잠자기
    case working       // 작업 중 — 타이핑
    case needsInput    // 확인 필요 — 손 흔들기
    case done          // 완료 — 기뻐하기
    case error         // 에러 — 당황
    case playing       // 놀기 — 돌아다니기

    var displayName: String {
        displayName(for: AppLanguage.saved)
    }

    func displayName(for lang: AppLanguage) -> String {
        switch lang {
        case .ko:
            switch self {
            case .idle:       return "쉬는 중"
            case .working:    return "작업 중"
            case .needsInput: return "확인 필요!"
            case .done:       return "완료!"
            case .error:      return "에러 발생"
            case .playing:    return "놀고 있어요"
            }
        case .en:
            switch self {
            case .idle:       return "Resting"
            case .working:    return "Working"
            case .needsInput: return "Need Input!"
            case .done:       return "Done!"
            case .error:      return "Error"
            case .playing:    return "Playing"
            }
        case .ja:
            switch self {
            case .idle:       return "休憩中"
            case .working:    return "作業中"
            case .needsInput: return "確認して!"
            case .done:       return "完了!"
            case .error:      return "エラー"
            case .playing:    return "遊んでる"
            }
        case .zh:
            switch self {
            case .idle:       return "休息中"
            case .working:    return "工作中"
            case .needsInput: return "需要确认!"
            case .done:       return "完成!"
            case .error:      return "出错了"
            case .playing:    return "玩耍中"
            }
        }
    }
}
