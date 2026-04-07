import SpriteKit

/// 마스코트를 표시하는 SpriteKit 씬.
/// 투명 배경 위에 마스코트 + 미세한 그림자를 렌더링한다.
///
/// 앵커 포인트를 (0.5, 1.0) = 상단 중앙으로 설정하여
/// 윈도우 확장 시 마스코트 좌표가 자동으로 안정된다.
/// (윈도우는 좌우 대칭 + 아래로 확장되므로 상단 중앙은 항상 고정)
final class MascotScene: SKScene {

    private var mascotNode = MascotNode()
    private var backgroundNode: SKShapeNode?
    private var shadowNode: SKShapeNode?
    private var bubbleQueue: BubbleQueue?
    private var statusLabel: SKLabelNode?

    /// 마스코트의 기본 위치 (노치 오른쪽 가시 영역 중앙, 상단 중앙 앵커 기준)
    private var normalMascotPosition: CGPoint = .zero
    /// 상태 라벨의 기본 위치
    private var normalLabelPosition: CGPoint = .zero
    /// normal 모드에서 마스코트 위치를 제한하는 constraint
    private var normalConstraints: [SKConstraint]?

    /// 오프닝 재생 중 여부 (클릭 무시용)
    private(set) var isPlayingOpening = false

    // MARK: - Marquee

    private struct MarqueeItem {
        let cropNode: SKCropNode
        let label: SKLabelNode
        let overflow: CGFloat
        let rect: CGRect
    }

    private var marqueeItems: [MarqueeItem] = []
    private var activeMarqueeIndex: Int? = nil

    /// 크기 변경 요청 콜백 (NotchWindow에서 연결)
    var onSizeChangeRequested: ((MascotSize) -> Void)?

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
        setupShadow()
        setupStatusLabel()
        if isDesktopMode {
            updateMascotState(.idle)
        } else {
            playOpeningSequence()
        }
    }

    /// 현재 마스코트 상태 (NotchWindow에서 참조)
    var currentMascotState: MascotState { mascotNode.currentState }

    /// 현재 마스코트 셋 (NotchWindow에서 참조)
    var currentMascotSet: MascotSet { mascotNode.currentSet }

    /// 마스코트 셋을 변경한다.
    func changeMascotSet(_ set: MascotSet) {
        // 기존 마스코트 위치/상태 백업
        let pos = mascotNode.position
        let state = mascotNode.currentState

        // 기존 노드 완전 제거
        mascotNode.removeAllActions()
        mascotNode.removeFromParent()

        // 선택 저장 + S 사이즈 강제
        set.save()
        MascotSize.s.save()
        currentMascotSize = .s

        // 새 MascotNode를 UserDefaults 기반으로 생성 (= 앱 시작과 동일)
        let newNode = MascotNode()
        newNode.position = pos
        newNode.zPosition = 10
        addChild(newNode)
        mascotNode = newNode

        // 상태 + 말풍선 + 그림자 리셋
        newNode.forceSetState(state)
        bubbleQueue?.mascotNode = newNode
        bubbleQueue?.mascotSize = .s
        updateShadowForSize(.s)
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

        // 상태별 즉시 말풍선 (크기에 맞게 스케일)
        if let text = BubblePhrases.text(for: state) {
            let baseStyle: BubbleStyle
            let priority: BubblePriority
            switch state {
            case .error:
                baseStyle = .alert; priority = .critical
            case .needsInput:
                baseStyle = .alert; priority = .high
            case .done:
                baseStyle = .success; priority = .normal
            default:
                baseStyle = .normal; priority = .low
            }
            bubbleQueue?.forceShow(text: text, priority: priority, style: baseStyle)
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
        // No-op: expanded mode removed
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
        shadowNode?.alpha = 0
        statusLabel?.alpha = 0
    }

    /// 전환 완료 후 콘텐츠를 페이드인한다.
    func fadeInAfterTransition() {
        let fadeIn = SKAction.fadeIn(withDuration: 0.25)
        mascotNode.run(fadeIn)
        shadowNode?.run(fadeIn)
    }

    /// 모드 변경 시 레이아웃을 업데이트한다.
    func updateLayout(mode: NotchGeometry.DisplayMode, fromExpanded: Bool = false) {
        mascotNode.removeAction(forKey: "modeChange")

        switch mode {
        case .normal:
            // normal 모드: constraint 복원 (노치 영역 안에서만 이동)
            mascotNode.constraints = normalConstraints
            marqueeItems = []
            activeMarqueeIndex = nil

            // 즉시 위치/스케일 설정 (fadeInAfterTransition에서 페이드인)
            mascotNode.position = normalMascotPosition
            mascotNode.baseScale = 1.0
            mascotNode.setScale(1.0)
            backgroundNode?.fillColor = .clear  // 투명 복귀
            shadowNode?.position = CGPoint(
                x: normalMascotPosition.x,
                y: normalMascotPosition.y - MascotNode.maxHeight / 2 - 2
            )
            statusLabel?.fontSize = 11
            statusLabel?.position = normalLabelPosition
            // 상태 애니메이션 복원
            updateMascotState(mascotNode.currentState)
            statusLabel?.isHidden = true
            statusLabel?.alpha = 0

        }
    }

    /// 노치 모드에서 마스코트 X 위치를 설정한다 (드래그 드롭 위치 기반).
    func setMascotX(_ x: CGFloat) {
        // constraint 범위 내로 클램프
        let halfMascot = MascotNode.maxHeight / 2
        let windowHalfW = size.width / 2
        let minX = -windowHalfW + halfMascot + 4
        let maxX = windowHalfW - halfMascot - 4
        let clampedX = min(max(x, minX), maxX)

        normalMascotPosition = CGPoint(x: clampedX, y: normalMascotPosition.y)
        mascotNode.position = normalMascotPosition
        shadowNode?.position = CGPoint(
            x: clampedX,
            y: normalMascotPosition.y - MascotNode.maxHeight / 2 - 2
        )
    }

    // MARK: - Drag Feedback

    /// 드래그 시작/종료 시 시각 피드백
    func showDragFeedback(_ show: Bool) {
        if show {
            // 즉시 표시 후 스케일 애니메이션 (번쩍임 방지)
            mascotNode.alpha = 0.8
            mascotNode.setScale(mascotNode.baseScale)
            mascotNode.run(SKAction.scale(to: mascotNode.baseScale * 1.15, duration: 0.15), withKey: "dragFeedback")
            shadowNode?.alpha = 0
        } else {
            mascotNode.run(SKAction.group([
                SKAction.scale(to: mascotNode.baseScale, duration: 0.2),
                SKAction.fadeAlpha(to: 1.0, duration: 0.2)
            ]), withKey: "dragFeedback")
            shadowNode?.run(SKAction.fadeIn(withDuration: 0.2))
        }
    }

    /// 데스크탑 모드 레이아웃: 마스코트를 윈도우 중앙에 배치
    func updateDesktopLayout() {
        mascotNode.constraints = nil
        mascotNode.position = CGPoint(x: 0, y: -size.height / 2)
        mascotNode.baseScale = currentMascotSize.scale
        mascotNode.setScale(currentMascotSize.scale)
        mascotNode.alpha = 1

        shadowNode?.position = CGPoint(x: 0, y: -size.height / 2 - MascotNode.maxHeight / 2 - 2)
        shadowNode?.alpha = 1

        statusLabel?.isHidden = true
        statusLabel?.alpha = 0

        marqueeItems = []
        activeMarqueeIndex = nil

        // 상태 애니메이션 + 말풍선 복원
        updateMascotState(mascotNode.currentState)
    }

    /// 데스크탑 모드 여부 (오프닝 스킵용)
    var isDesktopMode = false

    /// 현재 마스코트 크기 (노치=S, 데스크탑=S/M/L)
    private(set) var currentMascotSize: MascotSize = .s

    /// guard 없이 크기를 강제 설정한다 (모드 전환 시).
    func forceMascotSize(_ size: MascotSize) {
        currentMascotSize = size
        mascotNode.baseScale = size.scale
        mascotNode.setScale(size.scale)
        bubbleQueue?.mascotSize = size
        updateShadowForSize(size)
    }

    /// 마스코트 크기를 변경한다. 데스크탑 모드에서만 M/L 허용.
    func setMascotSize(_ size: MascotSize) {
        let effectiveSize = isDesktopMode ? size : .s
        guard effectiveSize != currentMascotSize else { return }
        currentMascotSize = effectiveSize
        effectiveSize.save()

        // baseScale 설정 (StateAnimations가 이 값을 기준으로 애니메이션)
        let newScale = effectiveSize.scale
        mascotNode.baseScale = newScale
        bubbleQueue?.mascotSize = effectiveSize
        print("[MascotScene] 크기 변경: \(effectiveSize.displayName), bubbleQueue.mascotSize=\(effectiveSize.displayName)")
        mascotNode.run(SKAction.scale(to: newScale, duration: 0.3), withKey: "sizeChange")

        // 그림자 크기 업데이트
        updateShadowForSize(effectiveSize)

        print("[MascotScene] 크기 변경: \(effectiveSize.displayName)")
    }

    /// 현재 크기에 맞는 BubbleStyle을 반환한다.
    func scaledBubbleStyle(_ base: BubbleStyle) -> BubbleStyle {
        base.scaled(for: currentMascotSize)
    }

    private func updateShadowForSize(_ size: MascotSize) {
        shadowNode?.removeFromParent()
        let shadow = SKShapeNode(ellipseOf: size.shadowSize)
        shadow.fillColor = NSColor(white: 0.0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.zPosition = 0.5
        shadow.glowWidth = 3.0 * size.scale
        // 크기별 그림자 간격: S=2, M=6, L=12
        let gap: CGFloat
        switch size {
        case .s: gap = 2
        case .m: gap = 6
        case .l: gap = 12
        }
        shadow.position = CGPoint(
            x: mascotNode.position.x,
            y: mascotNode.position.y - MascotNode.maxHeight * size.scale / 2 - gap
        )
        shadow.alpha = 1
        addChild(shadow)
        shadowNode = shadow
    }


    // MARK: - Marquee Scroll

    /// 마우스 이동 시 호출 — 긴 세션명 마키 스크롤
    func handleMouseMoved(at scenePoint: CGPoint) {
        guard !marqueeItems.isEmpty else { return }

        var hoveredIndex: Int? = nil
        for (i, item) in marqueeItems.enumerated() {
            if item.rect.contains(scenePoint) {
                hoveredIndex = i
                break
            }
        }

        if hoveredIndex == activeMarqueeIndex { return }

        // 이전 마키 중지 + 복귀
        if let prev = activeMarqueeIndex, prev < marqueeItems.count {
            let item = marqueeItems[prev]
            item.label.removeAction(forKey: "marquee")
            item.label.run(SKAction.moveTo(x: 0, duration: 0.2), withKey: "marqueeReset")
        }

        // 새 마키 시작
        if let idx = hoveredIndex {
            let item = marqueeItems[idx]
            item.label.removeAction(forKey: "marqueeReset")
            let scrollSpeed: CGFloat = 40
            let duration = TimeInterval(item.overflow / scrollSpeed)
            let scroll = SKAction.moveBy(x: -item.overflow, y: 0, duration: duration)
            let pause = SKAction.wait(forDuration: 0.8)
            let reset = SKAction.moveTo(x: 0, duration: 0.3)
            let pauseStart = SKAction.wait(forDuration: 0.5)
            item.label.run(
                SKAction.repeatForever(SKAction.sequence([pauseStart, scroll, pause, reset, pauseStart])),
                withKey: "marquee"
            )
        }

        activeMarqueeIndex = hoveredIndex
    }

    private func stateColor(_ state: MascotState, isEnded: Bool) -> NSColor {
        if isEnded { return NSColor(white: 0.35, alpha: 0.7) }
        switch state {
        case .working:    return NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        case .needsInput: return NSColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        case .error:      return NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        case .done:       return NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0)
        case .playing:    return NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0)
        case .idle:       return NSColor(white: 0.5, alpha: 0.7)
        }
    }


    // MARK: - Setup

    private func setupBackground() {
        // 배경 노드 유지 (expanded 전환 시 반투명으로 활용)
        // normal 모드에서는 투명 — 마스코트만 떠있는 형태
        let bg = SKShapeNode(rect: CGRect(x: -400, y: -600, width: 800, height: 600))
        bg.fillColor = .clear
        bg.strokeColor = .clear
        bg.lineWidth = 0
        bg.zPosition = -1
        addChild(bg)
        backgroundNode = bg
    }

    private func setupShadow() {
        let size = currentMascotSize
        let shadow = SKShapeNode(ellipseOf: size.shadowSize)
        shadow.fillColor = NSColor(white: 0.0, alpha: 0.25)
        shadow.strokeColor = .clear
        shadow.zPosition = 0.5
        let gap: CGFloat
        switch size {
        case .s: gap = 2
        case .m: gap = 6
        case .l: gap = 12
        }
        shadow.position = CGPoint(
            x: normalMascotPosition.x,
            y: normalMascotPosition.y - MascotNode.maxHeight * size.scale / 2 - gap
        )
        shadow.glowWidth = 3.0 * size.scale
        shadow.alpha = 0  // 오프닝 후 페이드인
        addChild(shadow)
        shadowNode = shadow
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

        // SKConstraint로 마스코트가 노치 양쪽 가시 영역 안에서 이동하도록 제한
        let halfMascot = MascotNode.maxHeight / 2
        let breathMargin: CGFloat = 3            // 호흡 애니메이션 여유분
        let windowRightX = normalFrame.width / 2
        let minX = windowLeftX + halfMascot + 4   // 윈도우 왼쪽 끝 + 여유
        let maxX = windowRightX - halfMascot - 4  // 윈도우 오른쪽 끝 + 여유 (노치 양쪽)
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

    /// 데스크탑→노치 전환 시 오프닝을 다시 재생한다.
    func replayOpening() {
        mascotNode.alpha = 0
        shadowNode?.alpha = 0
        playOpeningSequence()
    }

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

        // "Notch Buddy" 텍스트 — Claude 브랜드 오렌지 + 글로우
        // 글로우 레이어 (텍스트 뒤 미세한 발광)
        let glowNode = SKEffectNode()
        glowNode.shouldRasterize = true
        glowNode.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 2.0])
        let glowLabel = SKLabelNode(text: "Notch Buddy")
        glowLabel.fontName = "Menlo-Bold"
        glowLabel.fontSize = 11
        glowLabel.fontColor = NSColor(red: 0.96, green: 0.66, blue: 0.55, alpha: 0.4)
        glowLabel.horizontalAlignmentMode = .left
        glowNode.addChild(glowLabel)
        glowNode.position = CGPoint(x: notchLeftX, y: normalMascotPosition.y - 2)
        glowNode.zPosition = 4
        glowNode.alpha = 0
        addChild(glowNode)

        // 메인 텍스트 (Claude 오렌지)
        let titleLabel = SKLabelNode(text: "Notch Buddy")
        titleLabel.fontName = "Menlo-Bold"
        titleLabel.fontSize = 11
        titleLabel.fontColor = NSColor(red: 0.91, green: 0.49, blue: 0.36, alpha: 1.0)
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

        // 텍스트 + 글로우 동기 애니메이션
        let textFadeIn = SKAction.fadeIn(withDuration: 0.3)
        let textSlide = SKAction.moveBy(x: -80, y: 0, duration: 1.5)
        textSlide.timingMode = .easeInEaseOut
        let textFadeOut = SKAction.fadeOut(withDuration: 0.4)
        let textRemove = SKAction.removeFromParent()
        let textSequence = SKAction.sequence([
            textFadeIn,
            SKAction.group([textSlide, SKAction.sequence([SKAction.wait(forDuration: 1.0), textFadeOut])]),
            textRemove
        ])
        titleLabel.run(textSequence)
        glowNode.run(textSequence.copy() as! SKAction)

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
            self.shadowNode?.run(SKAction.fadeIn(withDuration: 0.3))
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
            let text = BubblePhrases.randomIdlePhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .low, style: .normal)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "idleBubble")
    }

    private func scheduleRepeatingBubble(state: MascotState) {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            let text = BubblePhrases.needsInputPhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .high, style: .alert)
        }
        run(SKAction.repeatForever(SKAction.sequence([show, wait])), withKey: "needsBubble")
    }

    private func schedulePlayingBubbles() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            let text = BubblePhrases.randomPlayingPhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .low, style: .normal)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "playBubble")
    }

    private func scheduleWorkingBubbles() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
            let text = BubblePhrases.workingPhrase()
            self?.bubbleQueue?.enqueue(text: text, priority: .low, style: .normal)
        }
        run(SKAction.repeatForever(SKAction.sequence([wait, show])), withKey: "workingBubble")
    }

    private func scheduleDoneBubbles() {
        let wait = SKAction.wait(forDuration: 12.5, withRange: 5) // 10~15초
        let show = SKAction.run { [weak self] in
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
        let bs = mascotNode.baseScale
        let stretchX = SKAction.scaleX(to: bs * 1.25, duration: 0.4)
        stretchX.timingMode = .easeInEaseOut
        let stretchY = SKAction.scaleY(to: bs * 0.8, duration: 0.4)
        stretchY.timingMode = .easeInEaseOut
        let hold = SKAction.wait(forDuration: 0.5)
        let backX = SKAction.scaleX(to: bs, duration: 0.3)
        backX.timingMode = .easeInEaseOut
        let backY = SKAction.scaleY(to: bs, duration: 0.3)
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
        let bs = mascotNode.baseScale
        let grow = SKAction.scale(to: bs * 1.3, duration: 0.5)
        grow.timingMode = .easeInEaseOut
        let tilt = SKAction.rotate(toAngle: 0.15, duration: 0.5)
        tilt.timingMode = .easeInEaseOut
        let hold = SKAction.wait(forDuration: 0.4)
        let shrink = SKAction.scale(to: bs, duration: 0.4)
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
        let bs = mascotNode.baseScale
        let jumpUp = SKAction.moveBy(x: 0, y: 6, duration: 0.1)
        jumpUp.timingMode = .easeOut
        let jumpDown = SKAction.moveBy(x: 0, y: -6, duration: 0.1)
        jumpDown.timingMode = .easeIn
        let pop = SKAction.scale(to: bs * 1.35, duration: 0.08)
        let unpop = SKAction.scale(to: bs, duration: 0.15)
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

    // MARK: - 프레임 업데이트 (그림자 추적)

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        // 그림자가 마스코트의 X 위치를 따라감 (보이는 경우만)
        guard let shadow = shadowNode, shadow.alpha > 0 else { return }
        shadow.position = CGPoint(x: mascotNode.position.x, y: shadow.position.y)
    }

}
