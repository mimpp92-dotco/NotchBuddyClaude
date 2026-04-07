import Foundation

/// 개별 세션 정보.
struct SessionInfo: Sendable {
    let sessionId: String
    let folderName: String
    var state: MascotState
    var lastEventKey: String      // raw 이벤트 키 (번역은 표시 시점)
    var lastToolName: String?     // 도구 이름 (있으면)
    var lastEventTime: Date
    var isEnded: Bool
    var terminalApp: TerminalApp

    /// 현재 언어에 맞는 이벤트 텍스트를 반환한다.
    var lastEventText: String {
        let lang = AppLanguage.saved
        switch lastEventKey {
        case "SessionStart":
            switch lang { case .ko: return "세션 시작"; case .en: return "Session started"; case .ja: return "セッション開始"; case .zh: return "会话开始" }
        case "PreToolUse":
            let tool = lastToolName ?? ""
            switch lang {
            case .ko: return tool.isEmpty ? "도구 사용 중" : "\(tool) 실행 중"
            case .en: return tool.isEmpty ? "Using tool" : "Running \(tool)"
            case .ja: return tool.isEmpty ? "ツール使用中" : "\(tool) 実行中"
            case .zh: return tool.isEmpty ? "使用工具中" : "\(tool) 执行中"
            }
        case "PostToolUse":
            let tool = lastToolName ?? ""
            switch lang {
            case .ko: return tool.isEmpty ? "도구 사용 완료" : "\(tool) 완료"
            case .en: return tool.isEmpty ? "Tool done" : "\(tool) done"
            case .ja: return tool.isEmpty ? "ツール完了" : "\(tool) 完了"
            case .zh: return tool.isEmpty ? "工具完成" : "\(tool) 完成"
            }
        case "Notification":
            switch lang { case .ko: return "확인 필요"; case .en: return "Need input"; case .ja: return "確認必要"; case .zh: return "需要确认" }
        case "Stop":
            switch lang { case .ko: return "작업 완료"; case .en: return "Task done"; case .ja: return "作業完了"; case .zh: return "任务完成" }
        case "SessionEnd":
            switch lang { case .ko: return "세션 종료"; case .en: return "Session ended"; case .ja: return "セッション終了"; case .zh: return "会话结束" }
        case "_stale":
            switch lang { case .ko: return "응답 없음"; case .en: return "No response"; case .ja: return "応答なし"; case .zh: return "无响应" }
        default:
            return lastEventKey
        }
    }
}

/// 여러 Claude Code 세션을 추적하고 대표 상태를 결정한다.
@MainActor
final class SessionManager {

    /// 세션 목록이 변경될 때 호출 (UI 갱신용)
    var onSessionsChanged: (([SessionInfo]) -> Void)?

    /// 대표 상태가 변경될 때 호출 (마스코트 상태 반영용)
    var onRepresentativeStateChanged: ((MascotState) -> Void)?

    /// 현재 대표 상태
    private(set) var representativeState: MascotState = .idle

    /// 세션 저장소 (session_id → SessionInfo)
    private var sessions: [String: SessionInfo] = [:]

    /// 오래된 세션 정리 타이머
    private var staleTimer: Timer?
    private let staleInterval: TimeInterval = 30  // 30초 무활동 → idle

    /// 정렬된 세션 목록 (최근 이벤트 순)
    var sortedSessions: [SessionInfo] {
        sessions.values.sorted { $0.lastEventTime > $1.lastEventTime }
    }

    /// 활성 세션 수
    var activeCount: Int {
        sessions.values.filter { !$0.isEnded }.count
    }

    // MARK: - 이벤트 처리

    /// stale 타이머를 시작한다.
    func startStaleTimer() {
        staleTimer?.invalidate()
        staleTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cleanStaleSessions()
            }
        }
    }

    /// 오래된 세션의 상태를 idle로 전환한다.
    private func cleanStaleSessions() {
        let now = Date()
        var changed = false

        for (id, session) in sessions {
            guard !session.isEnded else { continue }
            let elapsed = now.timeIntervalSince(session.lastEventTime)

            // needsInput, error, done: 30초 후 idle로 전환
            if elapsed > staleInterval && session.state != .idle && session.state != .working {
                var updated = session
                updated.state = .idle
                updated.lastEventKey = "_stale"
                updated.lastToolName = nil
                sessions[id] = updated
                changed = true
                print("[SessionManager] 세션 \(id.prefix(8))... stale → idle")
            }
        }

        if changed {
            updateRepresentativeState()
            onSessionsChanged?(sortedSessions)
        }
    }

    /// HookEvent를 받아 세션 정보를 업데이트한다.
    func handleEvent(_ event: HookEvent) {
        let sessionId = event.sessionId ?? "unknown"
        let folderName = extractFolderName(from: event.cwd)
        let state = resolveState(from: event)
        let isEnd = event.hookEventName == "SessionEnd"

        if var existing = sessions[sessionId] {
            existing.state = state
            existing.lastEventKey = event.hookEventName
            existing.lastToolName = event.toolName
            existing.lastEventTime = event.timestamp
            existing.isEnded = isEnd
            sessions[sessionId] = existing
        } else {
            // 종료된 세션 정리 (같은 폴더 & 종료됨 & 30초 이상 경과)
            let now = Date()
            let staleIds = sessions.filter {
                $0.value.folderName == folderName &&
                $0.key != sessionId &&
                $0.value.isEnded &&
                now.timeIntervalSince($0.value.lastEventTime) > 30
            }.map(\.key)
            for oldId in staleIds {
                sessions.removeValue(forKey: oldId)
            }

            // 새 세션: 앱 감지 (sourcePID로 정확한 매핑)
            let app = TerminalAppDetector.detect(cwd: event.cwd ?? "", sessionId: event.sessionId, sourcePID: event.sourcePID)
            sessions[sessionId] = SessionInfo(
                sessionId: sessionId,
                folderName: folderName,
                state: state,
                lastEventKey: event.hookEventName,
                lastToolName: event.toolName,
                lastEventTime: event.timestamp,
                isEnded: isEnd,
                terminalApp: app
            )
        }

        // 종료된 세션 제거하지 않고 유지 (흐리게 표시)
        print("[SessionManager] 세션 \(sessionId.prefix(8))... [\(folderName)] → \(state.displayName)")

        // 대표 상태 재계산
        updateRepresentativeState()

        // UI 콜백
        onSessionsChanged?(sortedSessions)
    }

    // MARK: - 대표 상태 결정

    /// 우선순위: needsInput > error > working > done > playing > idle
    /// 같은 우선순위면 최근 이벤트 기준
    private func updateRepresentativeState() {
        let activeSessions = sessions.values.filter { !$0.isEnded }

        guard !activeSessions.isEmpty else {
            setRepresentativeState(.idle)
            return
        }

        // 우선순위가 가장 높은 세션을 찾는다
        let best = activeSessions.max { a, b in
            let pa = statePriority(a.state)
            let pb = statePriority(b.state)
            if pa != pb { return pa < pb }
            return a.lastEventTime < b.lastEventTime
        }

        setRepresentativeState(best?.state ?? .idle)
    }

    private func setRepresentativeState(_ state: MascotState) {
        guard state != representativeState else { return }
        representativeState = state
        print("[SessionManager] 대표 상태: \(state.displayName)")
        onRepresentativeStateChanged?(state)
    }

    private func statePriority(_ state: MascotState) -> Int {
        switch state {
        case .needsInput: return 6
        case .error:      return 5
        case .working:    return 4
        case .done:       return 3
        case .playing:    return 2
        case .idle:       return 1
        }
    }

    // MARK: - 상태 매핑

    private func resolveState(from event: HookEvent) -> MascotState {
        switch event.hookEventName {
        case "SessionStart":       return .working
        case "PreToolUse":         return .working
        case "PostToolUse":        return .working
        case "PostToolUseFailure": return .error
        case "Notification":       return .needsInput
        case "Stop":               return .done
        case "SessionEnd":         return .idle
        default:                   return .idle
        }
    }

    // MARK: - 유틸리티

    private func extractFolderName(from cwd: String?) -> String {
        guard let cwd = cwd, !cwd.isEmpty else { return "unknown" }
        return (cwd as NSString).lastPathComponent
    }

}
