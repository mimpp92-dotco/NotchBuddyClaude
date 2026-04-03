import AppKit

/// 앱 라이프사이클을 관리하고 노치 윈도우를 생성한다.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var notchWindow: NotchWindow?
    private var statusItem: NSStatusItem?
    private var hookServer: HookServer?
    private var stateResolver: StateResolver?
    private(set) var sessionManager: SessionManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock에 표시하지 않음 (메뉴바 전용 앱)
        NSApp.setActivationPolicy(.accessory)

        // 노치 윈도우 생성 및 표시
        notchWindow = NotchWindow()
        notchWindow?.show()

        // Claude Code 상태 감지 시작
        setupClaudeMonitor()

        // 메뉴바 아이콘 설정
        setupStatusItem()

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

        // 4. 세션 매니저 → 리졸버 + UI 연결
        manager.onRepresentativeStateChanged = { [weak resolver] state in
            resolver?.updateRepresentativeState(state)
        }
        manager.onSessionsChanged = { [weak self] sessions in
            self?.notchWindow?.updateSessions(sessions)
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

    // MARK: - 메뉴바 아이콘

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "face.smiling.inverse", accessibilityDescription: "Claude Notch Buddy")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Claude Notch Buddy v1.0", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // 언어 선택 서브메뉴
        let langMenu = NSMenu()
        for lang in AppLanguage.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(changeLanguageFromMenu(_:)), keyEquivalent: "")
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

        let resetItem = NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func changeLanguageFromMenu(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? AppLanguage else { return }
        lang.save()
        // 메뉴 체크마크 업데이트
        setupStatusItem()
        // 마스코트 상태 텍스트 갱신
        notchWindow?.refreshLanguage()
    }

    @objc private func resetPosition() {
        notchWindow?.resetToNotch()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func screenDidChange() {
        notchWindow?.handleScreenChange()
    }
}
