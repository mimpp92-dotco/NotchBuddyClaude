import AppKit
import SpriteKit

/// 노치 영역에 표시되는 투명 오버레이 윈도우.
/// 노치를 좌우로 확장한 검은 영역 안에 마스코트가 산다.
/// 호버 시 살짝 커지고, 클릭 시 아래로 확장된다.
@MainActor
final class NotchWindow {

    let panel: NSPanel
    private let skView: SKView
    private let mascotScene: MascotScene
    private var currentMode: NotchGeometry.DisplayMode = .normal

    /// 설정 버튼 클릭 시 호출
    var onSettingsClicked: (() -> Void)?

    /// 사용자가 드래그로 위치를 변경했는지 여부
    private var hasCustomPosition: Bool {
        UserDefaults.standard.bool(forKey: "hasCustomPosition")
    }

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
        skView.layer?.cornerRadius = NotchGeometry.cornerRadius
        skView.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        skView.layer?.masksToBounds = true

        // MascotScene 생성
        mascotScene = MascotScene(size: frame.size)

        // 조립
        skView.presentScene(mascotScene)

        // SKView를 contentView로 설정
        panel.contentView = skView

        // 호버/클릭 감지용 투명 뷰를 SKView 위에 올림
        let interactionView = NotchInteractionView(frame: NSRect(origin: .zero, size: frame.size))
        interactionView.autoresizingMask = [.width, .height]
        interactionView.onClickedAt = { [weak self] viewPoint in
            guard let self else { return }

            // expanded 모드에서 클릭 처리
            if self.currentMode == .expanded {
                // NSView 좌표 → 씬 좌표 변환
                let scenePoint = self.skView.convert(viewPoint, to: self.mascotScene)

                // 설정 화면이 열려있으면 설정 화면 클릭 처리
                if self.mascotScene.isShowingSettings {
                    _ = self.mascotScene.handleSettingsClick(at: scenePoint)
                    return
                }

                // 설정 버튼 클릭
                if self.mascotScene.isSettingsButton(at: scenePoint) {
                    print("[NotchWindow] 설정 버튼 클릭")
                    self.mascotScene.showSettings()
                    return
                }

                // 세션 클릭 → 패널 축소 + 터미널 포커스
                if let sessionId = self.mascotScene.sessionIdAtPoint(scenePoint) {
                    print("[NotchWindow] 세션 클릭: \(sessionId.prefix(8))...")
                    self.toggleExpand()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        TerminalFocuser.focus()
                    }
                    return
                }

                // 빈 영역 클릭 → 축소
                self.toggleExpand()
                return
            }

            // normal 모드 — 항상 expand (터미널 포커스는 expanded에서 세션 클릭으로)
            let state = self.mascotScene.currentMascotState
            print("[NotchWindow] 클릭 — 현재 상태: \(state.displayName)")
            self.toggleExpand()
        }
        interactionView.onRightClicked = { [weak self] event in
            self?.showContextMenu(event: event)
        }

        skView.addSubview(interactionView)
    }

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
        setMode(.normal)
        UserDefaults.standard.set(false, forKey: "hasCustomPosition")
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
        // 강제로 노치 화면 위치 재계산
        let newFrame = NotchGeometry.calculateFrame(mode: currentMode)
        panel.setFrame(newFrame, display: true)
        mascotScene.size = newFrame.size
        mascotScene.updateLayout(mode: currentMode, fromExpanded: false)
    }

    // MARK: - 모드 전환

    private func setMode(_ mode: NotchGeometry.DisplayMode) {
        guard mode != currentMode else { return }

        let wasExpanded = (currentMode == .expanded)
        currentMode = mode

        // 공통: 전환 전 콘텐츠 숨기기 (검은 화면)
        mascotScene.hideForTransition()

        let newFrame = NotchGeometry.calculateFrame(mode: mode)

        // 약간 대기 후 리사이즈 → 레이아웃 → 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.panel.setFrame(newFrame, display: true)
            self.mascotScene.size = newFrame.size
            self.mascotScene.updateLayout(mode: mode, fromExpanded: wasExpanded)
            self.mascotScene.fadeInAfterTransition()
        }
    }

    private func toggleExpand() {
        if currentMode == .expanded {
            setMode(.normal)
        } else {
            setMode(.expanded)
        }
    }

    private func showContextMenu(event: NSEvent) {
        let menu = NSMenu()

        // 언어 선택 서브메뉴
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

        let resetItem = NSMenuItem(title: "Reset Position", action: #selector(resetFromMenu), keyEquivalent: "")
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
        // expanded 상태면 세션 리스트도 새로고침
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

/// 마우스 호버와 클릭 이벤트를 처리하는 뷰.
private final class NotchInteractionView: NSView {

    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onClickedAt: ((CGPoint) -> Void)?
    var onRightClicked: ((NSEvent) -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
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

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onClickedAt?(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClicked?(event)
    }
}
