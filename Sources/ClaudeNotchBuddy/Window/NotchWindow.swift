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
/// 투명 배경 위에 마스코트가 떠있고, expanded 시 블러 패널이 나타난다.
@MainActor
final class NotchWindow {

    let panel: NSPanel
    private let skView: SKView
    private let blurView: NSVisualEffectView
    private let mascotScene: MascotScene
    private var currentMode: NotchGeometry.DisplayMode = .normal
    private(set) var placementMode: PlacementMode = .notch

    /// 설정 버튼 클릭 시 호출
    var onSettingsClicked: (() -> Void)?

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

        // 블러 배경 (expanded 전용)
        blurView = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.isHidden = true
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 16
        blurView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        blurView.layer?.masksToBounds = true
        blurView.autoresizingMask = [.width, .height]

        // MascotScene 생성 (항상 노치에서 오프닝과 함께 시작)
        mascotScene = MascotScene(size: frame.size)

        // 크기 변경 콜백
        mascotScene.onSizeChangeRequested = { [weak self] size in
            self?.changeMascotSize(size)
        }

        // 조립
        skView.presentScene(mascotScene)

        // container: 블러(뒤) + SKView(앞)
        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.autoresizingMask = [.width, .height]
        container.addSubview(blurView)
        container.addSubview(skView)
        panel.contentView = container

        // 호버/클릭/드래그 감지용 투명 뷰를 SKView 위에 올림
        let interactionView = NotchInteractionView(frame: NSRect(origin: .zero, size: frame.size))
        interactionView.autoresizingMask = [.width, .height]

        interactionView.onClickedAt = { [weak self] viewPoint in
            self?.handleClick(at: viewPoint)
        }
        interactionView.onRightClicked = { [weak self] event in
            self?.showContextMenu(event: event)
        }
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

    /// 윈도우를 화면에 표시한다.
    func show() {
        panel.orderFrontRegardless()
    }

    /// 윈도우를 숨긴다.
    func hide() {
        panel.orderOut(nil)
    }

    /// 마스코트 상태를 변경한다.
    func updateState(_ state: MascotState) {
        mascotScene.updateMascotState(state)
    }

    /// 세션 목록을 업데이트한다.
    func updateSessions(_ sessions: [SessionInfo]) {
        mascotScene.updateSessions(sessions)
    }

    /// 노치 기본 위치로 리셋한다.
    func resetToNotch() {
        switchToNotchMode(dropScreenX: nil)
    }

    /// 마스코트 크기를 변경한다 (데스크탑 모드에서만 M/L 허용).
    func changeMascotSize(_ size: MascotSize) {
        mascotScene.setMascotSize(size)
        // 설정 패널에서 크기 변경 시에는 expanded 상태를 유지
        // (switchToDesktopMode 호출하면 expanded가 리셋됨)
    }

    /// 언어 변경 후 UI를 갱신한다.
    func refreshLanguage() {
        mascotScene.updateMascotState(mascotScene.currentMascotState)
        if currentMode == .expanded {
            mascotScene.updateSessions(mascotScene.currentSessions)
        }
    }

    /// 화면 변경 시 위치를 재계산한다.
    func handleScreenChange() {
        if placementMode.isNotch {
            let newFrame = NotchGeometry.calculateFrame(mode: currentMode)
            panel.setFrame(newFrame, display: true)
            blurView.frame = NSRect(origin: .zero, size: newFrame.size)
            skView.frame = NSRect(origin: .zero, size: newFrame.size)
            mascotScene.size = newFrame.size
            mascotScene.updateLayout(mode: currentMode, fromExpanded: false)
        }
        // 데스크탑 모드에서는 위치 유지
    }

    // MARK: - 클릭 처리

    private func handleClick(at viewPoint: CGPoint) {
        // expanded 모드에서 클릭 처리
        if currentMode == .expanded {
            let scenePoint = skView.convert(viewPoint, to: mascotScene)

            if mascotScene.isShowingSettings {
                _ = mascotScene.handleSettingsClick(at: scenePoint)
                return
            }

            if mascotScene.isSettingsButton(at: scenePoint) {
                print("[NotchWindow] 설정 버튼 클릭")
                mascotScene.showSettings()
                return
            }

            if let sessionId = mascotScene.sessionIdAtPoint(scenePoint) {
                print("[NotchWindow] 세션 클릭: \(sessionId.prefix(8))...")
                toggleExpand()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    TerminalFocuser.focus()
                }
                return
            }

            toggleExpand()
            return
        }

        // normal 모드 — expand
        let state = mascotScene.currentMascotState
        print("[NotchWindow] 클릭 — 현재 상태: \(state.displayName)")
        toggleExpand()
    }

    // MARK: - 드래그 처리

    /// 드래그 시작 시 커서 대비 윈도우 오프셋
    private var dragOffset: NSPoint = .zero

    private func handleDragStarted() {
        // expanded 상태면 먼저 축소
        if currentMode == .expanded {
            currentMode = .normal
            blurView.isHidden = true
            mascotScene.hideForTransition()
        }

        // 노치 모드: 넓은 윈도우를 포터블 사이즈로 축소
        // 리사이즈 전 콘텐츠 숨김 (번쩍임 방지)
        mascotScene.hideForTransition()
        if placementMode.isNotch {
            let sizeScale = MascotSize.saved.scale
            let mascotPt = MascotNode.defaultSize * sizeScale
            let bubbleRoom: CGFloat = 120 + 40 * sizeScale
            let portableSize = CGSize(
                width: mascotPt + 40 + bubbleRoom * 2,
                height: mascotPt + 40
            )
            // 현재 마우스 커서의 화면 좌표
            let mouseScreen = NSEvent.mouseLocation
            let portableOrigin = NSPoint(
                x: mouseScreen.x - portableSize.width / 2,
                y: mouseScreen.y - portableSize.height / 2
            )
            let portableFrame = NSRect(origin: portableOrigin, size: portableSize)
            panel.setFrame(portableFrame, display: true)
            blurView.frame = NSRect(origin: .zero, size: portableSize)
            skView.frame = NSRect(origin: .zero, size: portableSize)
            mascotScene.size = portableSize
            mascotScene.updateDesktopLayout()
        }

        // 드래그 중 statusBar 레벨로 전환 (노치 영역까지 이동 가능하도록)
        panel.level = .statusBar

        // 드래그 오프셋 기록 (커서와 윈도우 원점의 차이)
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
        // 오프셋을 유지하면서 윈도우 이동 (마스코트가 커서에 붙어있음)
        let newOrigin = NSPoint(
            x: screenPoint.x - dragOffset.x,
            y: screenPoint.y - dragOffset.y
        )
        panel.setFrameOrigin(newOrigin)
    }

    private func handleDragEnded(_ center: NSPoint) {
        // 드래그 피드백 해제 전에 모드 전환 (모드가 baseScale을 결정)
        if NotchGeometry.isInNotchZone(screenPoint: center) {
            mascotScene.forceMascotSize(.s)  // S로 먼저 설정 후 피드백 해제
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
        currentMode = .normal
        mascotScene.isDesktopMode = false
        mascotScene.forceMascotSize(.s)  // 노치 = S 강제 (guard 무시)

        let notchFrame = NotchGeometry.calculateFrame(mode: .normal)
        panel.setFrame(notchFrame, display: true)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        blurView.frame = NSRect(origin: .zero, size: notchFrame.size)
        blurView.isHidden = true
        skView.frame = NSRect(origin: .zero, size: notchFrame.size)
        mascotScene.size = notchFrame.size
        mascotScene.updateLayout(mode: .normal, fromExpanded: false)

        // 드래그로 복귀한 경우: 드롭 X 위치에 마스코트 배치
        if let screenX = dropScreenX {
            let sceneX = screenX - notchFrame.midX  // 화면 좌표 → 씬 좌표 (앵커 0.5 기준)
            mascotScene.setMascotX(sceneX)
        }

        mascotScene.fadeInAfterTransition()

        savePlacement()
        print("[NotchWindow] 노치 모드로 전환")
    }

    func switchToDesktopMode(at center: NSPoint) {
        placementMode = .desktop(center)
        currentMode = .normal
        mascotScene.isDesktopMode = true

        // 저장된 데스크탑 크기 복원 (노치에서 올 때)
        let desktopSize = MascotSize.saved
        if desktopSize != .s {
            mascotScene.setMascotSize(desktopSize)
        }

        let sizeScale = mascotScene.currentMascotSize.scale
        let mascotPt = MascotNode.defaultSize * sizeScale
        let padding: CGFloat = 20
        let bubbleRoom: CGFloat = 120 + 40 * sizeScale  // M/L일수록 더 넓은 말풍선 공간
        let windowSize = CGSize(
            width: mascotPt + padding * 2 + bubbleRoom * 2,  // 좌우 대칭 여유
            height: mascotPt + padding * 2
        )
        let windowOrigin = NSPoint(
            x: center.x - windowSize.width / 2,
            y: center.y - windowSize.height / 2
        )
        let desktopFrame = NSRect(origin: windowOrigin, size: windowSize)

        panel.setFrame(desktopFrame, display: true)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

        blurView.frame = NSRect(origin: .zero, size: desktopFrame.size)
        blurView.isHidden = true
        skView.frame = NSRect(origin: .zero, size: desktopFrame.size)
        mascotScene.size = desktopFrame.size
        mascotScene.updateDesktopLayout()

        savePlacement()
        print("[NotchWindow] 데스크탑 모드로 전환: (\(Int(center.x)), \(Int(center.y)))")
    }

    private func setMode(_ mode: NotchGeometry.DisplayMode) {
        guard mode != currentMode else { return }

        let wasExpanded = (currentMode == .expanded)
        currentMode = mode

        mascotScene.hideForTransition()

        // 노치 모드: 기존 방식
        if placementMode.isNotch {
            let newFrame = NotchGeometry.calculateFrame(mode: mode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.panel.setFrame(newFrame, display: true)
                self.blurView.frame = NSRect(origin: .zero, size: newFrame.size)
                self.skView.frame = NSRect(origin: .zero, size: newFrame.size)
                self.blurView.isHidden = (mode == .normal)
                self.mascotScene.size = newFrame.size
                self.mascotScene.updateLayout(mode: mode, fromExpanded: wasExpanded)
                self.mascotScene.fadeInAfterTransition()
            }
            return
        }

        // 데스크탑 모드
        if case .desktop(let center) = placementMode {
            if mode == .expanded {
                let (expandedFrame, direction) = NotchGeometry.calculateDesktopExpandedFrame(
                    mascotCenter: center
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self else { return }
                    self.panel.setFrame(expandedFrame, display: true)
                    self.blurView.frame = NSRect(origin: .zero, size: expandedFrame.size)
                    self.skView.frame = NSRect(origin: .zero, size: expandedFrame.size)
                    self.blurView.isHidden = false
                    self.blurView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                    self.mascotScene.size = expandedFrame.size
                    self.mascotScene.updateDesktopExpandedLayout(direction: direction)
                    self.mascotScene.fadeInAfterTransition()
                }
            } else {
                // normal로 복귀
                switchToDesktopMode(at: center)
            }
        }
    }

    private func toggleExpand() {
        if currentMode == .expanded {
            setMode(.normal)
        } else {
            setMode(.expanded)
        }
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

    // MARK: - 컨텍스트 메뉴

    private func showContextMenu(event: NSEvent) {
        let menu = NSMenu()

        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            if lang == AppLanguage.saved {
                item.state = .on
            }
            langMenu.addItem(item)
        }
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(NSMenuItem.separator())

        let resetItem = NSMenuItem(title: "Reset to Notch", action: #selector(resetFromMenu), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitFromMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: skView)
    }

    @objc private func changeLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? AppLanguage else { return }
        lang.save()
        mascotScene.updateMascotState(mascotScene.currentMascotState)
        if currentMode == .expanded {
            mascotScene.updateSessions(mascotScene.currentSessions)
        }
    }

    @objc private func resetFromMenu() {
        resetToNotch()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }
}

// MARK: - NotchInteractionView

/// 마우스 호버, 클릭, 롱프레스 드래그를 처리하는 뷰.
private final class NotchInteractionView: NSView {

    // 제스처 상태
    private enum InteractionState {
        case idle
        case waitingLongPress
        case dragging
    }

    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseMoved: ((CGPoint) -> Void)?
    var onClickedAt: ((CGPoint) -> Void)?
    var onRightClicked: ((NSEvent) -> Void)?
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
                // 미세한 떨림 → 타이머 취소, 클릭도 아닌 것으로 처리
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
            // 롱프레스 전 마우스 업 → 클릭
            let point = convert(event.locationInWindow, from: nil)
            onClickedAt?(point)

        case .dragging:
            // 드래그 완료 → 모드 판정
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
        onRightClicked?(event)
    }
}
