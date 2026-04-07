import AppKit

/// 세션 상태 요약.
struct StatusSummary {
    let workingCount: Int
    let needsInputCount: Int
    let doneCount: Int
    let totalActive: Int

    static let empty = StatusSummary(workingCount: 0, needsInputCount: 0, doneCount: 0, totalActive: 0)

    init(workingCount: Int = 0, needsInputCount: Int = 0, doneCount: Int = 0, totalActive: Int = 0) {
        self.workingCount = workingCount
        self.needsInputCount = needsInputCount
        self.doneCount = doneCount
        self.totalActive = totalActive
    }

    init(from sessions: [SessionInfo]) {
        let active = sessions.filter { !$0.isEnded }
        workingCount = active.filter { $0.state == .working }.count
        needsInputCount = active.filter { $0.state == .needsInput }.count
        doneCount = active.filter { $0.state == .done }.count
        totalActive = active.count
    }
}

/// SessionManager 콜백 → SwiftUI @Published 브릿지.
@MainActor
final class PopoverViewModel: ObservableObject {
    @Published var sessions: [SessionInfo] = []
    @Published var summary: StatusSummary = .empty

    // 설정 상태
    @Published var currentLanguage: AppLanguage = AppLanguage.saved
    @Published var currentSize: MascotSize = MascotSize.saved
    @Published var currentMascot: MascotSet = MascotSet.saved
    @Published var isShowingSettings: Bool = false
    @Published var isShowingMascotSelector: Bool = false

    // 콜백 (AppDelegate에서 설정)
    var onSessionClicked: ((SessionInfo) -> Void)?
    var onLanguageChanged: ((AppLanguage) -> Void)?
    var onSizeChanged: ((MascotSize) -> Void)?
    var onMascotChanged: ((MascotSet) -> Void)?

    /// SessionManager의 세션 목록을 반영한다.
    func updateSessions(_ sessions: [SessionInfo]) {
        self.sessions = sessions
        self.summary = StatusSummary(from: sessions)
    }
}
