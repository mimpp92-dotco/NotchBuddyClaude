import Foundation

/// 대표 상태에 대한 비활성 타이머를 관리한다.
/// 상태 매핑은 SessionManager가 담당하고, 이 클래스는 타이머만 관리한다.
@MainActor
final class StateResolver {

    /// 상태가 변경될 때 호출
    var onStateChanged: ((MascotState) -> Void)?

    /// 현재 대표 상태
    private(set) var currentState: MascotState = .idle

    /// 비활성 타이머 (30초 무활동 → .playing)
    private var inactivityTimer: Timer?
    private let inactivityInterval: TimeInterval = 30

    /// 대표 상태가 변경되었을 때 호출한다.
    func updateRepresentativeState(_ state: MascotState) {
        resetInactivityTimer()

        if state != currentState {
            currentState = state
            print("[StateResolver] 대표 상태 변경: \(state.displayName)")
            onStateChanged?(state)
        }
    }

    // MARK: - 비활성 타이머

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()

        // idle 상태에서는 타이머 불필요
        guard currentState != .idle else { return }

        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: inactivityInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // working 상태에서만 놀기로 전환
                // needsInput, error, done은 사용자가 확인할 때까지 유지
                if self.currentState == .working {
                    self.currentState = .playing
                    print("[StateResolver] 30초 무활동 → 놀기 모드")
                    self.onStateChanged?(.playing)
                }
            }
        }
    }
}
