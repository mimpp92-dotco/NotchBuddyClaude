import AppKit
import SwiftUI

/// 앱 라이프사이클을 관리하고 노치 윈도우를 생성한다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {

    private var notchWindow: NotchWindow?
    private var statusItem: NSStatusItem?
    private var hookServer: HookServer?
    private var stateResolver: StateResolver?
    private(set) var sessionManager: SessionManager?

    private var popover: NSPopover?
    private var popoverViewModel: PopoverViewModel?
    private var clickOutsideMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock에 표시하지 않음 (메뉴바 전용 앱)
        NSApp.setActivationPolicy(.accessory)

        // 노치 윈도우 생성 및 표시 (항상 노치에서 오프닝과 함께 시작)
        notchWindow = NotchWindow()
        notchWindow?.show()

        // Claude Code 상태 감지 시작
        setupClaudeMonitor()

        // 메뉴바 아이콘 + 팝오버 설정
        setupStatusItem()

        // 마스코트 클릭 → 팝오버 열기 연결
        notchWindow?.onPopoverRequested = { [weak self] in
            self?.togglePopover(nil)
        }

        // 화면 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        hookServer?.stop()
        notchWindow?.hide()
    }

    // MARK: - Claude Monitor

    private func setupClaudeMonitor() {
        // 1. 훅 자동 설정
        HookInstaller.installIfNeeded()

        // 2. 세션 매니저 생성
        let manager = SessionManager()
        sessionManager = manager

        // 3. 상태 리졸버 생성 (비활성 타이머 관리)
        let resolver = StateResolver()
        resolver.onStateChanged = { [weak self] state in
            self?.notchWindow?.updateState(state)
        }
        stateResolver = resolver

        // 4. 세션 매니저 → 리졸버 + UI + 팝오버 연결 (팬아웃)
        manager.onRepresentativeStateChanged = { [weak resolver] state in
            resolver?.updateRepresentativeState(state)
        }
        manager.onSessionsChanged = { [weak self] sessions in
            self?.notchWindow?.updateSessions(sessions)
            self?.popoverViewModel?.updateSessions(sessions)
        }

        // 5. Stale 세션 정리 타이머 시작
        manager.startStaleTimer()

        // 6. HTTP 서버 시작
        let server = HookServer()
        server.onEvent = { [weak manager] event in
            Task { @MainActor in
                manager?.handleEvent(event)
            }
        }
        server.start()
        hookServer = server
    }

    // MARK: - 메뉴바 아이콘 + 팝오버

    private func setupStatusItem() {
        // ViewModel 생성
        let vm = PopoverViewModel()
        vm.onSessionClicked = { [weak self] session in
            self?.closePopover()
            let app = session.terminalApp
            // 팝오버 활성화(NSApp.activate) 후 다른 앱으로 전환하려면
            // 우리 앱을 먼저 비활성화해야 함
            NSApp.deactivate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                TerminalFocuser.focus(app: app)
            }
        }
        vm.onLanguageChanged = { [weak self] lang in
            self?.notchWindow?.refreshLanguage()
        }
        vm.onSizeChanged = { [weak self] size in
            self?.notchWindow?.changeMascotSize(size)
        }
        vm.onMascotChanged = { [weak self] set in
            self?.notchWindow?.changeMascotSet(set)
            // 마스코트 변경 시 S 사이즈로 리셋 → 설정 UI에도 반영
            self?.popoverViewModel?.currentSize = .s
        }
        popoverViewModel = vm

        // 팝오버 생성
        let pop = NSPopover()
        pop.contentViewController = NSHostingController(
            rootView: PopoverPanel(viewModel: vm)
        )
        pop.behavior = .transient  // 바깥 클릭 시 자동 닫힘
        pop.delegate = self
        popover = pop

        // 메뉴바 아이콘 생성
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Claude 마스코트 PNG를 메뉴바 아이콘으로 사용
            if let url = ResourceBundle.bundle.url(forResource: "claude", withExtension: "png"),
               let mascotImage = NSImage(contentsOf: url) {
                mascotImage.size = NSSize(width: 18, height: 18)
                mascotImage.isTemplate = false
                button.image = mascotImage
            } else {
                button.image = NSImage(systemSymbolName: "face.smiling.inverse", accessibilityDescription: "Claude Notch Buddy")
                button.image?.size = NSSize(width: 18, height: 18)
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    // MARK: - Actions

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            // 현재 세션 + 설정 상태 최신화
            if let sessions = sessionManager?.sortedSessions {
                popoverViewModel?.updateSessions(sessions)
            }
            popoverViewModel?.currentLanguage = AppLanguage.saved
            popoverViewModel?.currentSize = notchWindow?.currentMascotSize ?? MascotSize.saved
            popoverViewModel?.currentMascot = MascotSet.saved
            // 팝오버를 key window로 만들어 첫 클릭이 즉시 반응하도록
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func closePopover() {
        popover?.close()
    }

    /// 팝오버가 닫힐 때 호출 (transient 닫힘 포함)
    func popoverDidClose(_ notification: Notification) {
        popoverViewModel?.isShowingSettings = false
        popoverViewModel?.isShowingMascotSelector = false
    }

    @objc private func screenDidChange() {
        notchWindow?.handleScreenChange()
    }
}
