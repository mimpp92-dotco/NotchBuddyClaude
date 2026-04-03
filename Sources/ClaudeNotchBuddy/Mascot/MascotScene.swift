import SpriteKit

/// 마스코트를 표시하는 SpriteKit 씬.
/// 노치를 좌우로 확장한 검은 둥근 배경 + 마스코트 캐릭터를 렌더링한다.
///
/// 앵커 포인트를 (0.5, 1.0) = 상단 중앙으로 설정하여
/// 윈도우 확장 시 마스코트 좌표가 자동으로 안정된다.
/// (윈도우는 좌우 대칭 + 아래로 확장되므로 상단 중앙은 항상 고정)
final class MascotScene: SKScene {

    private let mascotNode = MascotNode()
    private var backgroundNode: SKShapeNode?
    private var bubbleQueue: BubbleQueue?
    private var statusLabel: SKLabelNode?

    /// 마스코트의 기본 위치 (노치 오른쪽 가시 영역 중앙, 상단 중앙 앵커 기준)
    private var normalMascotPosition: CGPoint = .zero
    /// 상태 라벨의 기본 위치
    private var normalLabelPosition: CGPoint = .zero
    /// normal 모드에서 마스코트 위치를 제한하는 constraint
    private var normalConstraints: [SKConstraint]?

    // MARK: - Expanded UI

    /// expanded 모드 UI 컨테이너
    private var expandedContainer: SKNode?
    /// 세션 아이템 위치 (클릭 감지용)
    private var sessionItems: [(rect: CGRect, sessionId: String)] = []
    /// 설정 버튼 영역
    private var settingsButtonRect: CGRect = .zero
    /// 현재 세션 데이터
    private(set) var currentSessions: [SessionInfo] = []
    /// 현재 expanded 모드 여부
    private var isExpanded = false
    /// 오프닝 재생 중 여부 (클릭 무시용)
    private(set) var isPlayingOpening = false

    // MARK: - Settings UI

    /// 설정 화면 컨테이너
    private var settingsContainer: SKNode?
    /// 설정 화면 표시 여부
    private(set) var isShowingSettings = false
    /// 설정 화면에서 선택 중인 언어 인덱스
    private var languageIndex: Int = 0
    /// 설정 UI 클릭 영역
    private var prevButtonRect: CGRect = .zero
    private var nextButtonRect: CGRect = .zero
    private var confirmButtonRect: CGRect = .zero
    private var closeButtonRect: CGRect = .zero

    override init(size: CGSize) {
        super.init(size: size)
        self.backgroundColor = .clear
        self.scaleMode = .resizeFill
        self.anchorPoint = CGPoint(x: 0.5, y: 1.0)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        setupBackground()
        setupMascot()
        setupStatusLabel()
        playOpeningSequence()
    }

    /// 현재 마스코트 상태 (NotchWindow에서 참조)
    var currentMascotState: MascotState { mascotNode.currentState }

    /// 현재 마스코트 셋 (NotchWindow에서 참조)
    var currentMascotSet: MascotSet { mascotNode.currentSet }

    /// 마스코트 셋을 변경한다.
    func changeMascotSet(_ set: MascotSet) {
        mascotNode.setMascotSet(set)
    }

    /// 마스코트 상태를 변경한다.
    func updateMascotState(_ state: MascotState) {
        mascotNode.forceSetState(state)
        statusLabel?.text = state.displayName

        // 기존 스케줄 모두 제거
        removeAction(forKey: "idleBubble")
        removeAction(forKey: "needsBubble")
        removeAction(forKey: "playBubble")
        removeAction(forKey: "doneParticle")
        removeAction(forKey: "doneBubble")
        removeAction(forKey: "errorParticle")
        removeAction(forKey: "workingParticle")
        removeAction(forKey: "needsParticle")
        removeAction(forKey: "playingParticle")
        removeAction(forKey: "randomReaction")
        mascotNode.removeAction(forKey: "reactionAnim")

        // 말풍선 큐 + emitter 초기화
        bubbleQueue?.clear()
        removeDoneEmitter()
        removeErrorEmitter()
        removeWorkingEmitter()
        removeNeedsEmitter()
        removePlayingEmitter()

        // expanded 모드에서는 말풍선 비활성화
        guard !isExpanded else { return }

        // 상태별 즉시 말풍선
        if let text = BubblePhrases.text(for: state) {
            let style: BubbleStyle
            let priority: BubblePriority
            switch state {
            case .error:
                style = .alert; priority = .critical
            case .needsInput:
                style = .alert; priority = .high
            case .done:
                style = .success; priority = .normal
            default:
                style = .normal; priority = .low
            }
            bubbleQueue?.forceShow(text: text, priority: priority, style: style)
        }

        // 반복 말풍선 + 파티클 스케줄
        switch state {
        case .idle:
            scheduleIdleBubble()
            scheduleRandomReactions()
        case .needsInput:
            scheduleRepeatingBubble(state: state)
        case .playing:
            schedulePlayingBubbles()
            scheduleRandomReactions()
        case .done:
            scheduleDoneParticles()
            scheduleDoneBubbles()
        case .working:
            scheduleWorkingBubbles()
        case .error:
            scheduleErrorParticles()
        }
    }

    /// 세션 데이터를 업데이트한다.
    func updateSessions(_ sessions: [SessionInfo]) {
        currentSessions = sessions
        if isExpanded {
            renderSessionList()
        }
    }

    /// 클릭 좌표에서 세션 ID를 반환한다 (없으면 nil).
    /// point는 씬 좌표계 (앵커 0.5, 1.0 기준).
    func sessionIdAtPoint(_ point: CGPoint) -> String? {
        for item in sessionItems {
            if item.rect.contains(point) {
                return item.sessionId
            }
        }
        return nil
    }

    /// 클릭 좌표가 설정 버튼인지 확인한다.
    func isSettingsButton(at point: CGPoint) -> Bool {
        settingsButtonRect.contains(point)
    }

    /// 윈도우 리사이즈 전 모든 콘텐츠를 즉시 숨긴다 (배경만 남김).
    func hideForTransition() {
        mascotNode.removeAllActions()
        removeAction(forKey: "idleBubble")
        removeAction(forKey: "needsBubble")
        removeAction(forKey: "playBubble")
        removeAction(forKey: "doneBubble")
        removeAction(forKey: "workingBubble")
        removeAction(forKey: "doneParticle")
        removeAction(forKey: "errorParticle")
        removeAction(forKey: "randomReaction")
        bubbleQueue?.clear()
        removeDoneEmitter()
        removeErrorEmitter()
        removeWorkingEmitter()
        removeNeedsEmitter()
        removePlayingEmitter()

        mascotNode.alpha = 0
        mascotNode.zRotation = 0
        mascotNode.xScale = 1.0
        mascotNode.yScale = 1.0
        statusLabel?.alpha = 0
        expandedContainer?.alpha = 0
    }

    /// 전환 완료 후 콘텐츠를 페이드인한다.
    func fadeInAfterTransition() {
        let fadeIn = SKAction.fadeIn(withDuration: 0.25)
        mascotNode.run(fadeIn)
        if isExpanded {
            expandedContainer?.run(fadeIn)
            statusLabel?.run(fadeIn)
        }
    }

    /// 모드 변경 시 레이아웃을 업데이트한다.
    func updateLayout(mode: NotchGeometry.DisplayMode, fromExpanded: Bool = false) {
        mascotNode.removeAction(forKey: "modeChange")

        switch mode {
        case .normal:
            isExpanded = false
            // normal 모드: constraint 복원 (노치 영역 안에서만 이동)
            mascotNode.constraints = normalConstraints
            // 말풍선 스케줄 복원
            updateMascotState(mascotNode.currentState)

            // 설정 화면 + expanded UI 제거
            if isShowingSettings { closeSettings() }
            expandedContainer?.removeFromParent()
            expandedContainer = nil
            sessionItems = []

            // 즉시 위치/스케일 설정 (fadeInAfterTransition에서 페이드인)
            mascotNode.position = normalMascotPosition
            mascotNode.setScale(1.0)
            statusLabel?.fontSize = 11
            statusLabel?.position = normalLabelPosition
            // 상태 애니메이션 복원
            updateMascotState(mascotNode.currentState)
            statusLabel?.isHidden = true
            statusLabel?.alpha = 0

        case .expanded:
            isExpanded = true
            // expanded 모드: constraint 해제 (전체 패널 영역 사용)
            mascotNode.constraints = nil
            // 말풍선 비활성화
            removeAction(forKey: "idleBubble")
            removeAction(forKey: "needsBubble")
            removeAction(forKey: "playBubble")
            bubbleQueue?.clear()

            // 즉시 위치/스케일 설정 (fadeInAfterTransition에서 페이드인)
            let notchH: CGFloat = 38
            let visibleH = size.height - notchH
            let leftCenterX = -size.width / 4
            let centerY = -(notchH + visibleH * 0.4)

            mascotNode.position = CGPoint(x: leftCenterX, y: centerY)
            mascotNode.setScale(2.0)

            // 상태 라벨을 마스코트 아래에 (충분한 간격)
            statusLabel?.isHidden = false
            statusLabel?.alpha = 1
            statusLabel?.fontSize = 11
            statusLabel?.fontColor = NSColor(white: 0.5, alpha: 1.0)
            statusLabel?.position = CGPoint(x: leftCenterX, y: centerY - 50)

            // 상태 애니메이션 복원 (hideForTransition에서 제거됨)
            mascotNode.forceSetState(mascotNode.currentState)

            // expanded UI 생성
            setupExpandedUI()
        }
    }

    // MARK: - Expanded UI

    private func setupExpandedUI() {
        expandedContainer?.removeFromParent()

        let container = SKNode()
        container.zPosition = 5
        addChild(container)
        expandedContainer = container

        let notchH: CGFloat = 38
        let padding: CGFloat = 16
        let rightHalfLeft: CGFloat = 10  // 구분선 오른쪽

        // 구분선 (왼쪽 마스코트 영역 | 오른쪽 세션 리스트)
        let dividerH = size.height - notchH - 24
        let divider = SKShapeNode(rectOf: CGSize(width: 0.5, height: dividerH))
        divider.fillColor = NSColor(white: 0.15, alpha: 1.0)
        divider.strokeColor = .clear
        divider.position = CGPoint(x: 0, y: -(notchH + dividerH / 2 + 12))
        container.addChild(divider)

        // "세션" 헤더 (간결하게)
        let header = SKLabelNode(text: "SESSIONS")
        header.fontName = "Menlo-Bold"
        header.fontSize = 11
        header.fontColor = NSColor(white: 0.6, alpha: 1.0)
        header.horizontalAlignmentMode = .left
        header.position = CGPoint(x: rightHalfLeft + padding, y: -(notchH + 18))
        container.addChild(header)

        // 설정 버튼 (우상단)
        let settingsLabel = SKLabelNode(text: "Language")
        settingsLabel.fontName = "Menlo"
        settingsLabel.fontSize = 10
        settingsLabel.fontColor = NSColor(white: 0.55, alpha: 1.0)
        settingsLabel.horizontalAlignmentMode = .right
        let settingsX = size.width / 2 - padding
        let settingsY = -(notchH + 18)
        settingsLabel.position = CGPoint(x: settingsX, y: settingsY)
        container.addChild(settingsLabel)
        settingsButtonRect = CGRect(x: settingsX - 60, y: settingsY - 8, width: 68, height: 24)

        // 세션 리스트 렌더링
        renderSessionList()
    }

    private func renderSessionList() {
        // 기존 세션 노드 제거
        expandedContainer?.children
            .filter { $0.name == "sessionItem" }
            .forEach { $0.removeFromParent() }
        sessionItems = []

        guard let container = expandedContainer else { return }

        let notchH: CGFloat = 38
        let padding: CGFloat = 16
        let startY = -(notchH + 38)
        let itemHeight: CGFloat = 36
        let leftX: CGFloat = 10 + padding
        let rightX = size.width / 2 - padding

        if currentSessions.isEmpty {
            let emptyText: String = {
                switch AppLanguage.saved {
                case .ko: return "활성 세션 없음"
                case .en: return "No active sessions"
                case .ja: return "アクティブセッションなし"
                case .zh: return "没有活跃会话"
                }
            }()
            let empty = SKLabelNode(text: emptyText)
            empty.fontName = "Menlo"
            empty.fontSize = 11
            empty.fontColor = NSColor(white: 0.5, alpha: 1.0)
            empty.horizontalAlignmentMode = .left
            empty.position = CGPoint(x: leftX, y: startY - 30)
            empty.name = "sessionItem"
            container.addChild(empty)
            return
        }

        let maxVisible = min(currentSessions.count, 4)

        for i in 0..<maxVisible {
            let session = currentSessions[i]
            let itemY = startY - CGFloat(i) * itemHeight

            let itemNode = SKNode()
            itemNode.name = "sessionItem"

            // 상태 인디케이터 (작은 원) — 왼쪽에 배치
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = stateColor(session.state, isEnded: session.isEnded)
            dot.strokeColor = .clear
            dot.position = CGPoint(x: leftX, y: itemY + 3)
            itemNode.addChild(dot)

            // 폴더명 — dot 오른쪽
            let folderLabel = SKLabelNode(text: session.folderName)
            folderLabel.fontName = "Menlo-Bold"
            folderLabel.fontSize = 12
            folderLabel.fontColor = session.isEnded
                ? NSColor(white: 0.4, alpha: 1.0)
                : NSColor(white: 0.9, alpha: 1.0)
            folderLabel.horizontalAlignmentMode = .left
            folderLabel.position = CGPoint(x: leftX + 12, y: itemY)
            itemNode.addChild(folderLabel)

            // 마지막 이벤트 텍스트
            let eventLabel = SKLabelNode(text: session.lastEventText)
            eventLabel.fontName = "Menlo"
            eventLabel.fontSize = 11
            eventLabel.fontColor = session.isEnded
                ? NSColor(white: 0.35, alpha: 1.0)
                : NSColor(white: 0.55, alpha: 1.0)
            eventLabel.horizontalAlignmentMode = .left
            eventLabel.position = CGPoint(x: leftX + 12, y: itemY - 14)
            itemNode.addChild(eventLabel)

            container.addChild(itemNode)

            // 클릭 영역 (구분선부터 오른쪽 끝까지 넉넉하게)
            let itemRect = CGRect(x: 0, y: itemY - 20, width: rightX + 4, height: itemHeight)
            sessionItems.append((rect: itemRect, sessionId: session.sessionId))
        }
    }

    private func stateColor(_ state: MascotState, isEnded: Bool) -> NSColor {
        if isEnded { return NSColor(white: 0.25, alpha: 1.0) }
        switch state {
        case .working:    return NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        case .needsInput: return NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        case .error:      return NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        case .done:       return NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
        case .playing:    return NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0)
        case .idle:       return NSColor(white: 0.4, alpha: 1.0)
        }
    }

    // MARK: - Settings UI

    /// 설정 화면(언어 선택)을 표시한다.
    func showSettings() {
        guard isExpanded, !isShowingSettings else { return }
        isShowingSettings = true
        languageIndex = AppLanguage.allCases.firstIndex(of: AppLanguage.saved) ?? 0

        // expanded UI + 마스코트 숨기기
        expandedContainer?.alpha = 0
        mascotNode.alpha = 0
        statusLabel?.alpha = 0

        let container = SKNode()
        container.zPosition = 10
        addChild(container)
        settingsContainer = container

        let notchH: CGFloat = 38
        let visibleH = size.height - notchH
        let centerX: CGFloat = 0

        // Language 헤더
        let globeLabel = SKLabelNode(text: "Language")
        globeLabel.fontName = "Menlo-Bold"
        globeLabel.fontSize = 13
        globeLabel.fontColor = NSColor(white: 0.6, alpha: 1.0)
        let globeY = -(notchH + visibleH * 0.28)
        globeLabel.position = CGPoint(x: centerX, y: globeY)
        container.addChild(globeLabel)

        // 언어 이름
        let allLangs = AppLanguage.allCases
        let nameY = globeY - 50
        let nameLabel = SKLabelNode(text: allLangs[languageIndex].displayName)
        nameLabel.fontName = "Menlo-Bold"
        nameLabel.fontSize = 14
        nameLabel.fontColor = NSColor(white: 0.85, alpha: 1.0)
        nameLabel.position = CGPoint(x: centerX, y: nameY)
        nameLabel.name = "settingsName"
        container.addChild(nameLabel)

        // ◀ 이전
        let prevLabel = SKLabelNode(text: "◀")
        prevLabel.fontSize = 12
        prevLabel.fontColor = NSColor(white: 0.5, alpha: 1.0)
        let prevX = centerX - 70
        prevLabel.position = CGPoint(x: prevX, y: nameY)
        container.addChild(prevLabel)
        prevButtonRect = CGRect(x: prevX - 16, y: nameY - 10, width: 32, height: 28)

        // ▶ 다음
        let nextLabel = SKLabelNode(text: "▶")
        nextLabel.fontSize = 12
        nextLabel.fontColor = NSColor(white: 0.5, alpha: 1.0)
        let nextX = centerX + 70
        nextLabel.position = CGPoint(x: nextX, y: nameY)
        container.addChild(nextLabel)
        nextButtonRect = CGRect(x: nextX - 16, y: nameY - 10, width: 32, height: 28)

        // ✕ 닫기
        let closeLabel = SKLabelNode(text: "✕")
        closeLabel.fontName = "Menlo"
        closeLabel.fontSize = 13
        closeLabel.fontColor = NSColor(white: 0.35, alpha: 1.0)
        let closeX = size.width / 2 - 18
        let closeY = -(notchH + 16)
        closeLabel.position = CGPoint(x: closeX, y: closeY)
        container.addChild(closeLabel)
        closeButtonRect = CGRect(x: closeX - 14, y: closeY - 10, width: 28, height: 28)

        // 확인 버튼
        let confirmLabel = SKLabelNode(text: "OK")
        confirmLabel.fontName = "Menlo-Bold"
        confirmLabel.fontSize = 12
        confirmLabel.fontColor = NSColor(red: 0.4, green: 0.75, blue: 1.0, alpha: 1.0)
        let confirmY = -(size.height - 18)
        confirmLabel.position = CGPoint(x: centerX, y: confirmY)
        container.addChild(confirmLabel)
        confirmButtonRect = CGRect(x: centerX - 30, y: confirmY - 10, width: 60, height: 28)
    }

    /// 설정 화면을 닫는다 (저장 없이).
    func closeSettings() {
        settingsContainer?.removeFromParent()
        settingsContainer = nil
        isShowingSettings = false

        // expanded UI 복원
        expandedContainer?.alpha = 1
        mascotNode.alpha = 1
        statusLabel?.alpha = 1
    }

    /// 설정을 확인하고 닫는다 (언어 변경 저장).
    func confirmSettings() {
        let allLangs = AppLanguage.allCases
        let selected = allLangs[languageIndex]
        selected.save()
        // 상태 라벨 즉시 갱신
        statusLabel?.text = mascotNode.currentState.displayName
        closeSettings()
        // expanded UI 세션 리스트 즉시 새로고침 (언어 반영)
        if isExpanded {
            renderSessionList()
        }
    }

    /// 설정 화면에서 이전 언어로 변경한다.
    func settingsPrev() {
        let allLangs = AppLanguage.allCases
        languageIndex = (languageIndex - 1 + allLangs.count) % allLangs.count
        updateSettingsPreview()
    }

    /// 설정 화면에서 다음 언어로 변경한다.
    func settingsNext() {
        let allLangs = AppLanguage.allCases
        languageIndex = (languageIndex + 1) % allLangs.count
        updateSettingsPreview()
    }

    /// 설정 화면 클릭 처리. 처리한 경우 true.
    func handleSettingsClick(at point: CGPoint) -> Bool {
        guard isShowingSettings else { return false }

        if closeButtonRect.contains(point) {
            closeSettings()
            return true
        }
        if confirmButtonRect.contains(point) {
            confirmSettings()
            return true
        }
        if prevButtonRect.contains(point) {
            settingsPrev()
            return true
        }
        if nextButtonRect.contains(point) {
            settingsNext()
            return true
        }
        return true  // 설정 화면에서는 다른 클릭 무시
    }

    private func updateSettingsPreview() {
        let allLangs = AppLanguage.allCases
        let lang = allLangs[languageIndex]

        if let nameLabel = settingsContainer?.childNode(withName: "settingsName") as? SKLabelNode {
            nameLabel.text = lang.displayName
        }
    }

    // MARK: - Setup

    private func setupBackground() {
        // 배경은 충분히 크게 그리고, 둥근 모서리는 SKView layer에서 처리
        // 윈도우 크기가 변해도 배경 재생성 불필요
        let bg = SKShapeNode(rect: CGRect(x: -400, y: -600, width: 800, height: 600))
        bg.fillColor = NSColor.black
        bg.strokeColor = .clear
        bg.lineWidth = 0
        bg.zPosition = -1
        addChild(bg)
        backgroundNode = bg
    }

    private func setupMascot() {
        // 앵커 (0.5, 1.0) 기준: x=0이 윈도우 중앙, y<0이 아래
        // 노치 오른쪽 가시 영역(노치 우측~윈도우 우측)의 중앙에 배치
        let info = NotchGeometry.getNotchInfo()
        let normalFrame = NotchGeometry.calculateFrame(mode: .normal)

        // 비대칭 윈도우에서 노치의 씬 좌표를 정확히 계산
        let windowCenterScreen = normalFrame.origin.x + normalFrame.width / 2
        let notchLeftX = info.notchLeft - windowCenterScreen
        let windowLeftX = -normalFrame.width / 2
        // 마스코트를 왼쪽 영역의 중앙에 배치 (물리적 노치와 윈도우 끝의 중간)
        let mascotX = (windowLeftX + notchLeftX) / 2 + 1

        normalMascotPosition = CGPoint(x: mascotX, y: -size.height / 2 - 1)
        mascotNode.position = normalMascotPosition
        mascotNode.zPosition = 1
        addChild(mascotNode)

        // SKConstraint로 마스코트가 왼쪽 가시 영역 안에서만 이동하도록 제한
        let halfMascot = MascotNode.maxHeight / 2
        let breathMargin: CGFloat = 3            // 호흡 애니메이션 여유분
        let minX = windowLeftX + halfMascot + 4   // 윈도우 왼쪽 끝 + 마스코트 반 + 여유
        let maxX = notchLeftX - halfMascot - 4    // 노치 왼쪽 끝 - 마스코트 반 - 여유
        let minY = -(size.height - halfMascot) - breathMargin  // 윈도우 하단 + 여유
        let maxY = -(halfMascot) + breathMargin                // 윈도우 상단 + 여유

        let xRange = SKRange(lowerLimit: minX, upperLimit: maxX)
        let yRange = SKRange(lowerLimit: minY, upperLimit: maxY)
        normalConstraints = [SKConstraint.positionX(xRange, y: yRange)]
        mascotNode.constraints = normalConstraints

        // 말풍선 큐 초기화 (오프닝 후 호흡/말풍선 시작)
        bubbleQueue = BubbleQueue(parentScene: self, mascotNode: mascotNode)
    }

    // MARK: - 오프닝 시퀀스

    private func playOpeningSequence() {
        isPlayingOpening = true

        let info = NotchGeometry.getNotchInfo()
        let normalFrame = NotchGeometry.calculateFrame(mode: .normal)
        let windowCenterScreen = normalFrame.origin.x + normalFrame.width / 2
        let notchLeftX = info.notchLeft - windowCenterScreen

        // 마스코트를 노치 오른쪽 경계(숨긴 상태)에서 시작
        let startX = notchLeftX + 5  // 노치 경계에서 살짝 빼꼼
        mascotNode.position = CGPoint(x: startX, y: normalMascotPosition.y)
        mascotNode.alpha = 0
        mascotNode.constraints = nil  // 오프닝 중 constraint 해제

        // "Notch Buddy" 텍스트 — 노치 경계에서 왼쪽으로 흘러감
        let titleLabel = SKLabelNode(text: "Notch Buddy")
        titleLabel.fontName = "Menlo-Bold"
        titleLabel.fontSize = 11
        titleLabel.fontColor = NSColor(white: 0.75, alpha: 1.0)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.position = CGPoint(x: notchLeftX, y: normalMascotPosition.y - 2)
        titleLabel.zPosition = 5
        titleLabel.alpha = 0
        addChild(titleLabel)

        // 시퀀스 타이밍:
        // 0.0s — 텍스트 페이드인 + 왼쪽으로 이동 (약 2초)
        // 2.2s — 텍스트 사라진 후 마스코트 빼꼼
        // 2.8s — 마스코트 쏘옥~ 중앙으로
        // 3.5s — 오프닝 완료

        // 텍스트 애니메이션
        let textFadeIn = SKAction.fadeIn(withDuration: 0.3)
        let textSlide = SKAction.moveBy(x: -80, y: 0, duration: 1.5)
        textSlide.timingMode = .easeInEaseOut
        let textFadeOut = SKAction.fadeOut(withDuration: 0.4)
        let textRemove = SKAction.removeFromParent()
        titleLabel.run(SKAction.sequence([
            textFadeIn,
            SKAction.group([textSlide, SKAction.sequence([SKAction.wait(forDuration: 1.0), textFadeOut])]),
            textRemove
        ]))

        // 마스코트 애니메이션 — 텍스트가 다 지나간 뒤 등장
        let peekDelay = SKAction.wait(forDuration: 2.0)
        let peekIn = SKAction.fadeIn(withDuration: 0.2)
        let peekMove = SKAction.moveTo(x: notchLeftX - 5, duration: 0.3)
        peekMove.timingMode = .easeOut

        let pausePeek = SKAction.wait(forDuration: 0.4)

        // 쏘옥~ 중앙으로
        let swooshMove = SKAction.moveTo(x: normalMascotPosition.x, duration: 0.4)
        swooshMove.timingMode = .easeOut
        let swooshPop = SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.15),
            SKAction.scale(to: 0.9, duration: 0.1),
            SKAction.scale(to: 1.05, duration: 0.08),
            SKAction.scale(to: 1.0, duration: 0.07),
        ])

        let finalize = SKAction.run { [weak self] in
            guard let self else { return }
            self.isPlayingOpening = false
            self.mascotNode.constraints = self.normalConstraints
            self.updateMascotState(.idle)
        }

        mascotNode.run(SKAction.sequence([
            peekDelay,
            peekIn,
            peekMove,
            pausePeek,
            SKAction.group([swooshMove, swooshPop]),
            finalize
        ]))
    }

    private func setupStatusLabel() {
        let info = NotchGeometry.getNotchInfo()
        let normalFrame = NotchGeometry.calculateFrame(mode: .normal)

        let notchLeftX = -info.notchWidth / 2
        let windowLeftX = -normalFrame.width / 2
        let leftVisibleCenter = (notchLeftX + windowLeftX) / 2

        normalLabelPosition = CGPoint(x: leftVisibleCenter, y: -size.height / 2 - 4)

        let label = SKLabelNode(text: MascotState.idle.displayName)
        label.fontName = "Menlo"
        label.fontSize = 11
        label.fontColor = NSColor(white: 0.7, alpha: 1.0)
        label.position = normalLabelPosition
        label.zPosition = 2
        label.isHidden = true
        label.alpha = 0
        addChild(label)
        statusLabel = label
    }

    // MARK: - 말풍선

    private func scheduleIdleBubble() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            guard self?.isExpanded == false else { return }
            let text = BubblePhrases.randomIdlePhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .low, style: .normal)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "idleBubble")
    }

    private func scheduleRepeatingBubble(state: MascotState) {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            guard self?.isExpanded == false else { return }
            let text = BubblePhrases.needsInputPhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .high, style: .alert)
        }
        run(SKAction.repeatForever(SKAction.sequence([show, wait])), withKey: "needsBubble")
    }

    private func schedulePlayingBubbles() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            guard self?.isExpanded == false else { return }
            let text = BubblePhrases.randomPlayingPhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .low, style: .normal)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "playBubble")
    }

    private func scheduleWorkingBubbles() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            guard self?.isExpanded == false else { return }
            let text = BubblePhrases.workingPhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .low, style: .normal)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "workingBubble")
    }

    private func scheduleDoneBubbles() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            guard self?.isExpanded == false else { return }
            let text = BubblePhrases.text(for: .done) ?? "완료!"
            self?.bubbleQueue?.enqueue(text: text, priority: .normal, style: .success)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "doneBubble")
    }

    /// done 파티클용 SKEmitterNode (상태 전환 시 제거)
    private var doneEmitter: SKEmitterNode?

    private func scheduleDoneParticles() {
        // SKEmitterNode 기반 연속 폭죽 파티클
        let emitter = SKEmitterNode()

        // 작은 원형 텍스처 (4x4)
        let texImage = NSImage(size: CGSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        emitter.particleTexture = SKTexture(image: texImage)

        // Fireflies 스타일: 반딧불처럼 느리게 떠다니며 깜빡임
        emitter.particleBirthRate = 8
        emitter.numParticlesToEmit = 0
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.8

        emitter.particleSpeed = 15
        emitter.particleSpeedRange = 10
        emitter.emissionAngleRange = .pi * 2

        emitter.particleScale = 0.8
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -0.2

        // 깜빡이는 알파: 밝아졌다 어두워졌다
        emitter.particleAlpha = 0.0
        emitter.particleAlphaRange = 0.0
        let alphaSeq = SKKeyframeSequence(keyframeValues: [
            NSNumber(value: 0.0),
            NSNumber(value: 1.0),
            NSNumber(value: 0.3),
            NSNumber(value: 1.0),
            NSNumber(value: 0.0),
        ], times: [0, 0.2, 0.5, 0.8, 1.0])
        alphaSeq.interpolationMode = .spline
        emitter.particleAlphaSequence = alphaSeq

        // 색상: 초록 → 금색 → 파랑 → 핑크
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0),
            NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0),
            NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0),
            NSColor(red: 1.0, green: 0.5, blue: 0.7, alpha: 1.0),
        ], times: [0, 0.33, 0.66, 1.0])

        emitter.position = .zero
        emitter.zPosition = 3
        emitter.targetNode = self  // 파티클이 씬 공간에서 독립 이동

        mascotNode.addChild(emitter)
        doneEmitter = emitter
    }

    private func removeDoneEmitter() {
        doneEmitter?.removeFromParent()
        doneEmitter = nil
    }

    // MARK: - Error 파티클 (Smoke 스타일)

    private var errorEmitter: SKEmitterNode?

    private func scheduleErrorParticles() {
        let emitter = makeCircleEmitter()

        // Smoke: 빨간 연기가 위로 피어오름
        emitter.particleBirthRate = 12
        emitter.particleLifetime = 1.2
        emitter.particleLifetimeRange = 0.4

        emitter.particleSpeed = 20
        emitter.particleSpeedRange = 10
        emitter.emissionAngle = .pi / 2  // 위쪽
        emitter.emissionAngleRange = .pi / 3

        emitter.particleScale = 0.6
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = 0.3  // 점점 커짐 (연기 퍼짐)

        emitter.particleAlpha = 0.8
        emitter.particleAlphaSpeed = -0.7

        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            NSColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 1.0),
            NSColor(red: 0.8, green: 0.15, blue: 0.1, alpha: 1.0),
            NSColor(red: 0.3, green: 0.1, blue: 0.1, alpha: 1.0),
        ], times: [0, 0.5, 1.0])

        emitter.position = .zero
        emitter.zPosition = 3
        emitter.targetNode = self
        mascotNode.addChild(emitter)
        errorEmitter = emitter
    }

    private func removeErrorEmitter() {
        errorEmitter?.removeFromParent()
        errorEmitter = nil
    }

    // MARK: - Working 파티클 (Spark 스타일)

    private var workingEmitter: SKEmitterNode?

    private func scheduleWorkingParticles() {
        let emitter = makeCircleEmitter()

        // Spark: 작은 불꽃이 사방으로 튐
        emitter.particleBirthRate = 10
        emitter.particleLifetime = 0.6
        emitter.particleLifetimeRange = 0.2

        emitter.particleSpeed = 50
        emitter.particleSpeedRange = 20
        emitter.emissionAngleRange = .pi * 2

        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.5

        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.5

        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),
            NSColor(red: 0.2, green: 0.3, blue: 0.8, alpha: 1.0),
        ], times: [0, 0.5, 1.0])

        emitter.position = .zero
        emitter.zPosition = 3
        emitter.targetNode = self
        mascotNode.addChild(emitter)
        workingEmitter = emitter
    }

    private func removeWorkingEmitter() {
        workingEmitter?.removeFromParent()
        workingEmitter = nil
    }

    // MARK: - NeedsInput 파티클 (Bokeh 스타일)

    private var needsEmitter: SKEmitterNode?

    private func scheduleNeedsInputParticles() {
        let emitter = makeCircleEmitter()

        // Bokeh: 주황 빛망울이 천천히 깜빡
        emitter.particleBirthRate = 5
        emitter.particleLifetime = 1.8
        emitter.particleLifetimeRange = 0.5

        emitter.particleSpeed = 12
        emitter.particleSpeedRange = 8
        emitter.emissionAngleRange = .pi * 2

        emitter.particleScale = 1.2
        emitter.particleScaleRange = 0.6
        emitter.particleScaleSpeed = -0.3

        emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [
            NSNumber(value: 0.0),
            NSNumber(value: 0.7),
            NSNumber(value: 0.2),
            NSNumber(value: 0.7),
            NSNumber(value: 0.0),
        ], times: [0, 0.25, 0.5, 0.75, 1.0])

        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0),
            NSColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0),
        ], times: [0, 1.0])

        emitter.position = .zero
        emitter.zPosition = 3
        emitter.targetNode = self
        mascotNode.addChild(emitter)
        needsEmitter = emitter
    }

    private func removeNeedsEmitter() {
        needsEmitter?.removeFromParent()
        needsEmitter = nil
    }

    // MARK: - Playing 파티클 (Fireflies 스타일)

    private var playingEmitter: SKEmitterNode?

    private func schedulePlayingParticles() {
        let emitter = makeCircleEmitter()

        // Fireflies: 파스텔 반딧불이 느리게 떠다님
        emitter.particleBirthRate = 4
        emitter.particleLifetime = 2.5
        emitter.particleLifetimeRange = 0.8

        emitter.particleSpeed = 10
        emitter.particleSpeedRange = 8
        emitter.emissionAngleRange = .pi * 2

        emitter.particleScale = 0.7
        emitter.particleScaleRange = 0.3
        emitter.particleScaleSpeed = -0.15

        emitter.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [
            NSNumber(value: 0.0),
            NSNumber(value: 0.8),
            NSNumber(value: 0.2),
            NSNumber(value: 0.8),
            NSNumber(value: 0.0),
        ], times: [0, 0.2, 0.5, 0.8, 1.0])

        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: [
            NSColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0),  // 핑크
            NSColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0), // 금색
            NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0),  // 보라
        ], times: [0, 0.5, 1.0])

        emitter.position = .zero
        emitter.zPosition = 3
        emitter.targetNode = self
        mascotNode.addChild(emitter)
        playingEmitter = emitter
    }

    private func removePlayingEmitter() {
        playingEmitter?.removeFromParent()
        playingEmitter = nil
    }

    // MARK: - 랜덤 리액션

    private func scheduleRandomReactions() {
        let wait = SKAction.wait(forDuration: 45, withRange: 30) // 30~60초 간격
        let react = SKAction.run { [weak self] in
            guard self?.isExpanded == false else { return }
            self?.playRandomReaction()
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, react])), withKey: "randomReaction")
    }

    private func playRandomReaction() {
        let reactions: [() -> Void] = [
            { self.reactionYawn() },
            { self.reactionBlink() },
            { self.reactionStretch() },
            { self.reactionSurprise() },
        ]
        reactions.randomElement()?()
    }

    /// 하품: 크게 늘어났다 복귀 + 말풍선
    private func reactionYawn() {
        let stretchX = SKAction.scaleX(to: 1.25, duration: 0.4)
        stretchX.timingMode = .easeInEaseOut
        let stretchY = SKAction.scaleY(to: 0.8, duration: 0.4)
        stretchY.timingMode = .easeInEaseOut
        let hold = SKAction.wait(forDuration: 0.5)
        let backX = SKAction.scaleX(to: 1.0, duration: 0.3)
        backX.timingMode = .easeInEaseOut
        let backY = SKAction.scaleY(to: 1.0, duration: 0.3)
        backY.timingMode = .easeInEaseOut
        let stretch = SKAction.group([stretchX, stretchY])
        let back = SKAction.group([backX, backY])
        mascotNode.run(SKAction.sequence([stretch, hold, back]), withKey: "reactionAnim")
        bubbleQueue?.enqueue(text: "하암~", priority: .low, style: .normal, duration: 1.5)
    }

    /// 깜빡임: 빠르게 투명 → 복귀 + 말풍선
    private func reactionBlink() {
        let dim = SKAction.fadeAlpha(to: 0.2, duration: 0.06)
        let bright = SKAction.fadeAlpha(to: 1.0, duration: 0.06)
        let pause = SKAction.wait(forDuration: 0.12)
        mascotNode.run(SKAction.sequence([dim, bright, pause, dim, bright, pause, dim, bright]), withKey: "reactionAnim")
        bubbleQueue?.enqueue(text: "👀", priority: .low, style: .normal, duration: 1.2)
    }

    /// 기지개: 크게 커지면서 기울임 + 말풍선
    private func reactionStretch() {
        let grow = SKAction.scale(to: 1.3, duration: 0.5)
        grow.timingMode = .easeInEaseOut
        let tilt = SKAction.rotate(toAngle: 0.15, duration: 0.5)
        tilt.timingMode = .easeInEaseOut
        let hold = SKAction.wait(forDuration: 0.4)
        let shrink = SKAction.scale(to: 1.0, duration: 0.4)
        shrink.timingMode = .easeInEaseOut
        let untilt = SKAction.rotate(toAngle: 0, duration: 0.4)
        untilt.timingMode = .easeInEaseOut
        let up = SKAction.group([grow, tilt])
        let down = SKAction.group([shrink, untilt])
        mascotNode.run(SKAction.sequence([up, hold, down]), withKey: "reactionAnim")
        bubbleQueue?.enqueue(text: "으으~", priority: .low, style: .normal, duration: 1.5)
    }

    /// 깜짝 놀람: 큰 점프 + scale pop + 말풍선
    private func reactionSurprise() {
        let jumpUp = SKAction.moveBy(x: 0, y: 6, duration: 0.1)
        jumpUp.timingMode = .easeOut
        let jumpDown = SKAction.moveBy(x: 0, y: -6, duration: 0.1)
        jumpDown.timingMode = .easeIn
        let pop = SKAction.scale(to: 1.35, duration: 0.08)
        let unpop = SKAction.scale(to: 1.0, duration: 0.15)
        unpop.timingMode = .easeOut
        let jump = SKAction.sequence([jumpUp, jumpDown])
        let scale = SKAction.sequence([pop, unpop])
        mascotNode.run(SKAction.group([jump, scale]), withKey: "reactionAnim")
        bubbleQueue?.enqueue(text: "엇!", priority: .low, style: .normal, duration: 1.2)
    }

    // MARK: - 공통 텍스처 헬퍼

    private func makeCircleEmitter() -> SKEmitterNode {
        let emitter = SKEmitterNode()
        let texImage = NSImage(size: CGSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.white.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        emitter.particleTexture = SKTexture(image: texImage)
        emitter.numParticlesToEmit = 0
        return emitter
    }

}
