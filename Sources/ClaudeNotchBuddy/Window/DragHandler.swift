import AppKit

/// 마우스 드래그로 윈도우를 이동시키는 핸들러.
/// 더블클릭 시 노치 기본 위치로 리셋하는 콜백을 지원한다.
@MainActor
final class DragHandler {

    private weak var window: NSWindow?

    /// 드래그로 위치가 변경되었을 때 호출
    var onPositionChanged: ((NSPoint) -> Void)?

    /// 더블클릭 시 호출
    var onDoubleClick: (() -> Void)?

    init(window: NSWindow) {
        self.window = window
    }

    /// SKView를 감싸는 드래그 가능한 뷰를 반환한다.
    func wrapView(_ contentView: NSView) -> NSView {
        let draggableView = DraggableView(frame: contentView.bounds)
        draggableView.autoresizingMask = [.width, .height]
        draggableView.handler = self
        contentView.frame = draggableView.bounds
        contentView.autoresizingMask = [.width, .height]
        draggableView.addSubview(contentView)
        return draggableView
    }
}

// MARK: - DraggableView

/// 마우스 이벤트를 처리하는 커스텀 NSView.
private final class DraggableView: NSView {

    weak var handler: DragHandler?
    private var dragOrigin: NSPoint?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            handler?.onDoubleClick?()
            return
        }
        dragOrigin = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window, let origin = dragOrigin else { return }

        let current = event.locationInWindow
        let dx = current.x - origin.x
        let dy = current.y - origin.y

        var newOrigin = window.frame.origin
        newOrigin.x += dx
        newOrigin.y += dy
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        if dragOrigin != nil, let window = self.window {
            handler?.onPositionChanged?(window.frame.origin)
        }
        dragOrigin = nil
    }
}
