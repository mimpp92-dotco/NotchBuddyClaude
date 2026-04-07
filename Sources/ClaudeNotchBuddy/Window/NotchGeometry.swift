import AppKit

/// 노치 감지 및 윈도우 위치/크기 계산을 담당한다.
/// 실제 노치 좌표를 기반으로 좌우로 확장된 영역을 계산한다.
struct NotchGeometry {

    /// 노치 왼쪽으로 확장하는 여유 공간 (마스코트 + 말풍선 영역)
    static let leftExtension: CGFloat = 200
    /// 노치 오른쪽으로 확장하는 여유 공간 (양쪽 자유 배치)
    static let rightExtension: CGFloat = 200

    /// 둥근 모서리 반경
    static let cornerRadius: CGFloat = 16

    enum DisplayMode {
        case normal     // 기본: 노치 좌우 확장
    }

    // MARK: - 노치 감지

    /// 노치가 있는 화면을 찾는다. 없으면 메인 화면 반환.
    static func notchScreen() -> NSScreen {
        if #available(macOS 12, *) {
            for screen in NSScreen.screens {
                if screen.safeAreaInsets.top > 0 {
                    return screen
                }
            }
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    static func hasNotch(screen: NSScreen = notchScreen()) -> Bool {
        if #available(macOS 12, *) {
            return screen.safeAreaInsets.top > 0
        }
        return false
    }

    // MARK: - 노치 정보

    struct NotchInfo {
        let notchLeft: CGFloat    // 노치 왼쪽 끝 (화면 좌표)
        let notchRight: CGFloat   // 노치 오른쪽 끝 (화면 좌표)
        let notchWidth: CGFloat   // 노치 너비
        let notchHeight: CGFloat  // 노치 높이
        let screenFrame: NSRect   // 화면 전체 프레임
    }

    /// 실제 노치 정보를 가져온다.
    static func getNotchInfo(screen: NSScreen = notchScreen()) -> NotchInfo {
        let screenFrame = screen.frame

        if #available(macOS 12, *) {
            if let leftArea = screen.auxiliaryTopLeftArea,
               let rightArea = screen.auxiliaryTopRightArea {
                let notchLeft = screenFrame.origin.x + leftArea.maxX
                let notchRight = screenFrame.origin.x + rightArea.minX
                return NotchInfo(
                    notchLeft: notchLeft,
                    notchRight: notchRight,
                    notchWidth: notchRight - notchLeft,
                    notchHeight: screen.safeAreaInsets.top,
                    screenFrame: screenFrame
                )
            }
        }

        // 노치 없는 맥 기본값
        let center = screenFrame.midX
        return NotchInfo(
            notchLeft: center - 110,
            notchRight: center + 110,
            notchWidth: 220,
            notchHeight: 38,
            screenFrame: screenFrame
        )
    }

    // MARK: - 노치 스냅 판정

    /// 화면 좌표가 노치 Y 영역 안에 있는지 판정한다.
    /// 스냅 존: 물리적 노치 + 아래 50pt 여유
    static func isInNotchZone(screenPoint: NSPoint, screen: NSScreen = notchScreen()) -> Bool {
        let info = getNotchInfo(screen: screen)
        let notchTopY = info.screenFrame.maxY
        let snapMargin: CGFloat = 50
        let notchBottomY = notchTopY - info.notchHeight - snapMargin
        return screenPoint.y >= notchBottomY && screenPoint.y <= notchTopY
    }

    // MARK: - 윈도우 프레임 계산

    static func calculateFrame(
        mode: DisplayMode = .normal,
        for screen: NSScreen = notchScreen()
    ) -> NSRect {
        let info = getNotchInfo(screen: screen)

        let extraLeft = leftExtension
        let extraRight = rightExtension
        let extraBottom: CGFloat = 0

        // 윈도우: 노치 좌우 비대칭 확장 (왼쪽 넓게, 오른쪽 최소)
        let windowLeft = info.notchLeft - extraLeft
        let windowRight = info.notchRight + extraRight
        let windowWidth = windowRight - windowLeft
        let windowHeight = info.notchHeight + extraBottom

        // macOS 좌표계: y=0이 아래
        let windowY: CGFloat
        if hasNotch(screen: screen) {
            // 노치 있음: 화면 최상단에 배치 (기존 동작)
            windowY = info.screenFrame.maxY - windowHeight
        } else {
            // 노치 없음: 메뉴바 아래에 배치
            windowY = screen.visibleFrame.maxY
        }

        return NSRect(x: windowLeft, y: windowY, width: windowWidth, height: windowHeight)
    }

    /// 윈도우 좌표계에서 노치의 좌/우 경계를 반환한다 (마스코트 배치용).
    static func notchBoundsInWindow(
        mode: DisplayMode = .normal,
        for screen: NSScreen = notchScreen()
    ) -> (leftEnd: CGFloat, rightStart: CGFloat, windowWidth: CGFloat) {
        let info = getNotchInfo(screen: screen)
        let frame = calculateFrame(mode: mode, for: screen)

        // 윈도우 좌표계로 변환
        let leftEnd = info.notchLeft - frame.origin.x     // 윈도우 내에서 노치 왼쪽 끝
        let rightStart = info.notchRight - frame.origin.x  // 윈도우 내에서 노치 오른쪽 시작

        return (leftEnd, rightStart, frame.width)
    }
}
