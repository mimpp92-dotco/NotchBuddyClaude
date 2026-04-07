import AppKit
import SpriteKit

// MARK: - PlacementMode

enum PlacementMode: Equatable {
    case notch
    case desktop(CGPoint)

    var isNotch: Bool {
        if case .notch = self { return true }
        return false
    }

    var isDesktop: Bool {
        if case .desktop = self { return true }
        return false
    }
}

/// 노치 또는 데스크탑에 표시되는 투명 오버레이 윈도우.
/// 투명 배경 위에 마스코트가 떠있다.
@MainActor
final class NotchWindow {

    let panel: NSPanel
    private let skView: SKView
    private let mascotScene: MascotScene
    private(set) var placementMode: PlacementMode = .notch

    /// 마스코트 클릭 시 팝오버를 열도록 AppDelegate에서 설정
    var onPopoverRequested: (() -> Void)?

    /// 현재 마스코트 크기
    var currentMascotSize: MascotSize { mascotScene.currentMascotSize }

    init() {
        let frame = NotchGeometry.calculateFrame(mode: .normal)

        // NSPanel 생성 — borderless, nonactivating
        panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        // SpriteKit 뷰 설정
        skView = SKView(frame: NSRect(origin: .zero, size: frame.size))
        skView.allowsTransparency = true
        skView.wantsLayer = true
        skView.layer?.isOpaque = false
        skView.layer?.cornerRadius = 0
        skView.layer?.masksToBounds = false

        // MascotScene 생성 (항상 노치에서 오프닝과 함께 시작)
        mascotScene = MascotScene(size: frame.size)

        // 크기 변경 콜백
        mascotScene.onSizeChangeRequested = { [weak self] size in
            self?.changeMascotSize(size)
        }

        // 조립
        skView.presentScene(mascotScene)

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.autoresizingMask = [.width, .height]
        container.addSubview(skView)
        panel.contentView = container

        // 호버/클릭/드래그 감지용 투명 뷰를 SKView 위에 올림
        let interactionView = NotchInteractionView(frame: NSRect(origin: .zero, size: frame.size))
        interactionView.autoresizingMask = [.width, .height]

        interactionView.onClickedAt = { [weak self] viewPoint in
            self?.handleClick(at: viewPoint)
        }
        // 우클릭 비활성화 (팝오버로 통합됨)
        interactionView.onMouseMoved = { [weak self] viewPoint in
            guard let self else { return }
            let scenePoint = self.skView.convert(viewPoint, to: self.mascotScene)
            self.mascotScene.handleMouseMoved(at: scenePoint)
        }
        interactionView.onDragStarted = { [weak self] in
            self?.handleDragStarted()
        }
        interactionView.onDragMoved = { [weak self] screenPoint in
            self?.handleDragMoved(screenPoint)
        }
        interactionView.onDragEnded = { [weak self] screenPoint in
            self?.handleDragEnded(screenPoint)
        }

        skView.addSubview(interactionView)
    }

    // MARK: - Public API

    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func updateState(_ state: MascotState) {
        mascotScene.updateMascotState(state)
    }

    func updateSessions(_ sessions: [SessionInfo]) {
        mascotScene.updateSessions(sessions)
    }

    func resetToNotch() {
        switchToNotchMode(dropScreenX: nil)
    }

    func changeMascotSize(_ size: MascotSize) {
        mascotScene.setMascotSize(size)
    }

    func changeMascotSet(_ set: MascotSet) {
        mascotScene.changeMascotSet(set)
    }

    func refreshLanguage() {
        mascotScene.updateMascotState(mascotScene.currentMascotState)
    }

    func handleScreenChange() {
        if placementMode.isNotch {
            let newFrame = NotchGeometry.calculateFrame(mode: .normal)
            panel.setFrame(newFrame, display: true)
            skView.frame = NSRect(origin: .zero, size: newFrame.size)
            mascotScene.size = newFrame.size
            mascotScene.updateLayout(mode: .normal, fromExpanded: false)
        }
    }

    // MARK: - 클릭 처리

    private func handleClick(at viewPoint: CGPoint) {
        // 마스코트 클릭 → 팝오버 열기
        onPopoverRequested?()
    }

    // MARK: - 드래그 처리

    private var dragOffset: NSPoint = .zero

    private func handleDragStarted() {
        // 노치 모드: 넓은 윈도우를 포터블 사이즈로 축소
        mascotScene.hideForTransition()
        if placementMode.isNotch {
            let sizeScale = MascotSize.saved.scale
            let mascotPt = MascotNode.defaultSize * sizeScale
            let bubbleRoom: CGFloat = 120 + 40 * sizeScale
            let portableSize = CGSize(
                width: mascotPt + 40 + bubbleRoom * 2,
                height: mascotPt + 40
            )
            let mouseScreen = NSEvent.mouseLocation
            let portableOrigin = NSPoint(
                x: mouseScreen.x - portableSize.width / 2,
                y: mouseScreen.y - portableSize.height / 2
            )
            let portableFrame = NSRect(origin: portableOrigin, size: portableSize)
            panel.setFrame(portableFrame, display: true)
            skView.frame = NSRect(origin: .zero, size: portableSize)
            mascotScene.size = portableSize
            mascotScene.updateDesktopLayout()
        }

        // 드래그 중 statusBar 레벨로 전환 (노치 영역까지 이동 가능하도록)
        panel.level = .statusBar

        // 드래그 오프셋 기록
        let mouseScreen = NSEvent.mouseLocation
        dragOffset = NSPoint(
            x: mouseScreen.x - panel.frame.origin.x,
            y: mouseScreen.y - panel.frame.origin.y
        )

        // 포터블 윈도우에서 마스코트 표시 + 드래그 피드백
        mascotScene.updateDesktopLayout()
        mascotScene.showDragFeedback(true)
    }

    private func handleDragMoved(_ screenPoint: NSPoint) {
        let newOrigin = NSPoint(
            x: screenPoint.x - dragOffset.x,
            y: screenPoint.y - dragOffset.y
        )
        panel.setFrameOrigin(newOrigin)
    }

    private func handleDragEnded(_ center: NSPoint) {
        if NotchGeometry.isInNotchZone(screenPoint: center) {
            mascotScene.forceMascotSize(.s)
            mascotScene.showDragFeedback(false)
            switchToNotchMode(dropScreenX: center.x)
        } else {
            mascotScene.showDragFeedback(false)
            switchToDesktopMode(at: center)
        }
    }

    // MARK: - 모드 전환

    func switchToNotchMode(dropScreenX: CGFloat? = nil) {
        placementMode = .notch
        mascotScene.isDesktopMode = false
        mascotScene.forceMascotSize(.s)

        let notchFrame = NotchGeometry.calculateFrame(mode: .normal)
        panel.setFrame(notchFrame, display: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        skView.frame = NSRect(origin: .zero, size: notchFrame.size)
        mascotScene.size = notchFrame.size
        mascotScene.updateLayout(mode: .normal, fromExpanded: false)

        if let screenX = dropScreenX {
            let sceneX = screenX - notchFrame.midX
            mascotScene.setMascotX(sceneX)
        }

        mascotScene.fadeInAfterTransition()
        savePlacement()
    }

    func switchToDesktopMode(at center: NSPoint) {
        placementMode = .desktop(center)
        mascotScene.isDesktopMode = true

        // 노치에서 나올 때 현재 크기(S) 유지. 사용자가 설정에서 변경 가능.

        let sizeScale = mascotScene.currentMascotSize.scale
        let mascotPt = MascotNode.defaultSize * sizeScale
        let padding: CGFloat = 20
        let topRoom: CGFloat = 16  // 바운스/점프 시 머리 짤림 방지
        let bubbleRoom: CGFloat = 120 + 40 * sizeScale
        let windowSize = CGSize(
            width: mascotPt + padding * 2 + bubbleRoom * 2,
            height: mascotPt + padding * 2 + topRoom
        )
        let windowOrigin = NSPoint(
            x: center.x - windowSize.width / 2,
            y: center.y - windowSize.height / 2
        )
        let desktopFrame = NSRect(origin: windowOrigin, size: windowSize)

        panel.setFrame(desktopFrame, display: true)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        skView.frame = NSRect(origin: .zero, size: desktopFrame.size)
        mascotScene.size = desktopFrame.size
        mascotScene.updateDesktopLayout()
        mascotScene.fadeInAfterTransition()

        savePlacement()
    }

    // MARK: - 위치 저장/복원

    private func savePlacement() {
        switch placementMode {
        case .notch:
            UserDefaults.standard.set("notch", forKey: "placementMode")
        case .desktop(let point):
            UserDefaults.standard.set("desktop", forKey: "placementMode")
            UserDefaults.standard.set(Double(point.x), forKey: "desktopX")
            UserDefaults.standard.set(Double(point.y), forKey: "desktopY")
        }
    }

    static func loadPlacement() -> PlacementMode {
        let mode = UserDefaults.standard.string(forKey: "placementMode") ?? "notch"
        if mode == "desktop" {
            let x = UserDefaults.standard.double(forKey: "desktopX")
            let y = UserDefaults.standard.double(forKey: "desktopY")
            if x != 0 || y != 0 {
                return .desktop(CGPoint(x: x, y: y))
            }
        }
        return .notch
    }
}

// MARK: - NotchInteractionView

/// 마우스 호버, 클릭, 롱프레스 드래그를 처리하는 뷰.
private final class NotchInteractionView: NSView {

    private enum InteractionState {
        case idle
        case waitingLongPress
        case dragging
    }

    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?
    var onClickedAt: ((CGPoint) -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragMoved: ((NSPoint) -> Void)?
    var onDragEnded: ((NSPoint) -> Void)?

    private var interactionState: InteractionState = .idle
    private var longPressTimer: Timer?
    private var mouseDownPoint: NSPoint = .zero

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onMouseMoved?(point)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        interactionState = .waitingLongPress

        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if case .waitingLongPress = self.interactionState {
                    self.interactionState = .dragging
                    self.onDragStarted?()
                }
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let current = event.locationInWindow

        switch interactionState {
        case .waitingLongPress:
            let dx = current.x - mouseDownPoint.x
            let dy = current.y - mouseDownPoint.y
            if sqrt(dx * dx + dy * dy) > 3 {
                longPressTimer?.invalidate()
                longPressTimer = nil
                interactionState = .idle
            }

        case .dragging:
            guard let window = self.window else { return }
            let screenPoint = window.convertPoint(toScreen: current)
            onDragMoved?(screenPoint)

        case .idle:
            break
        }
    }

    override func mouseUp(with event: NSEvent) {
        longPressTimer?.invalidate()
        longPressTimer = nil

        switch interactionState {
        case .waitingLongPress:
            let point = convert(event.locationInWindow, from: nil)
            onClickedAt?(point)

        case .dragging:
            guard let window = self.window else { break }
            let center = NSPoint(
                x: window.frame.midX,
                y: window.frame.midY
            )
            onDragEnded?(center)

        case .idle:
            break
        }

        interactionState = .idle
    }

    override func rightMouseDown(with event: NSEvent) {
        // 우클릭 비활성화 (팝오버로 통합됨)
    }
}
