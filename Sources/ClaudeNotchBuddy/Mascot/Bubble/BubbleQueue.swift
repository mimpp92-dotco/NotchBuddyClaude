import SpriteKit

/// 말풍선 우선순위.
enum BubblePriority: Int, Comparable {
    case low = 0       // idle, playing 랜덤
    case normal = 1    // done
    case high = 2      // needsInput
    case critical = 3  // error

    static func < (lhs: BubblePriority, rhs: BubblePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// 말풍선 표시를 관리하는 큐.
/// 마스코트 위치에 따라 좌/우를 동적으로 결정한다.
final class BubbleQueue {

    private weak var parentScene: SKScene?
    private weak var mascotNode: SKNode?
    private var currentBubble: BubbleNode?
    private var currentPriority: BubblePriority = .low

    /// 왼쪽 가시 영역의 중앙 X (마스코트 위치 기준점)
    private var areaCenter: CGFloat = 0

    init(parentScene: SKScene, mascotNode: SKNode) {
        self.parentScene = parentScene
        self.mascotNode = mascotNode

        let info = NotchGeometry.getNotchInfo()
        let normalFrame = NotchGeometry.calculateFrame(mode: .normal)
        let windowCenterScreen = normalFrame.origin.x + normalFrame.width / 2
        let windowLeftX = -normalFrame.width / 2
        let notchLeftX = info.notchLeft - windowCenterScreen
        areaCenter = (windowLeftX + notchLeftX) / 2
    }

    /// 말풍선을 표시한다. 현재 말풍선보다 우선순위가 낮으면 무시.
    func enqueue(text: String, priority: BubblePriority = .low, style: BubbleStyle = .normal, duration: TimeInterval = 2.5) {
        guard let scene = parentScene, let mascot = mascotNode else { return }

        // 현재 말풍선보다 우선순위가 낮으면 무시
        if currentBubble != nil && currentBubble?.parent != nil && priority < currentPriority {
            return
        }

        dismissCurrent()

        let side = sideForMascot(at: mascot.position)
        let bubble = BubbleNode(text: text, side: side, style: style)
        let mascotWidth = (mascot as? SKSpriteNode)?.size.width ?? MascotNode.defaultSize
        bubble.show(in: mascot, mascotWidth: mascotWidth, duration: duration)

        currentBubble = bubble
        currentPriority = priority
    }

    /// 우선순위 무시하고 즉시 표시한다.
    func forceShow(text: String, priority: BubblePriority = .critical, style: BubbleStyle = .normal, duration: TimeInterval = 2.5) {
        dismissCurrent()

        guard let scene = parentScene, let mascot = mascotNode else { return }

        let side = sideForMascot(at: mascot.position)
        let bubble = BubbleNode(text: text, side: side, style: style)
        let mascotWidth = (mascot as? SKSpriteNode)?.size.width ?? MascotNode.defaultSize
        bubble.show(in: mascot, mascotWidth: mascotWidth, duration: duration)

        currentBubble = bubble
        currentPriority = priority
    }

    /// 현재 말풍선과 큐를 모두 비운다.
    func clear() {
        dismissCurrent()
        currentPriority = .low
    }

    // MARK: - Private

    private func dismissCurrent() {
        if let bubble = currentBubble, bubble.parent != nil {
            bubble.dismiss()
        }
        currentBubble = nil
    }

    /// 말풍선 방향을 랜덤으로 결정한다.
    private func sideForMascot(at position: CGPoint) -> BubbleSide {
        Bool.random() ? .right : .left
    }
}
