import SpriteKit

/// 마스코트 캐릭터를 표현하는 SpriteKit 노드.
/// Feature 1에서는 정적 이미지 + 호흡 애니메이션만 사용한다.
/// Feature 3에서 상태별 스프라이트 전환이 추가된다.
final class MascotNode: SKSpriteNode {

    private(set) var currentState: MascotState = .idle

    /// 현재 MascotSize에 따른 기본 스케일 (StateAnimations에 전달)
    var baseScale: CGFloat = 1.0

    internal var currentSet: MascotSet = .claude

    /// 스프라이트 시트 프레임 캐시 (spritecat 전용)
    private var spriteFrames: [MascotState: [SKTexture]]?

    /// 눈 깜빡임 노드
    private var leftEyelid: SKShapeNode?
    private var rightEyelid: SKShapeNode?

    /// 기본 마스코트 크기 (코드 생성 마스코트용)
    static let defaultSize: CGFloat = 34
    /// 노치 높이 기준 최대 크기
    static let maxHeight: CGFloat = 34

    /// 마스코트 셋에 맞는 표시 크기를 계산한다.
    static func displaySize(for set: MascotSet) -> CGSize {
        if set.isImageBased {
            // PNG 이미지: 비율 유지하면서 노치 높이에 맞춤
            let tex = set.generateTexture(size: CGSize(width: 28, height: 28))
            let aspect = tex.size().width / tex.size().height
            let h: CGFloat = set == .bichon ? maxHeight * 1.2 : maxHeight
            let w = h * aspect
            return CGSize(width: w, height: h)
        }
        if set.isSpriteSheet {
            // 스프라이트 시트: 프레임 내 캐릭터가 작으므로 크게 표시
            let s = maxHeight
            return CGSize(width: s, height: s)
        }
        let s = defaultSize
        return CGSize(width: s, height: s)
    }

    /// 저장된 마스코트 셋으로 생성한다.
    init() {
        let savedSet = MascotSet.saved
        let size = MascotNode.displaySize(for: savedSet)
        let texture = savedSet.generateTexture(size: CGSize(width: 28, height: 28))
        super.init(texture: texture, color: .clear, size: size)
        self.name = "mascot"
        self.currentSet = savedSet

        if savedSet.isSpriteSheet {
            spriteFrames = SpriteSheetLoader.loadFrames()
        }

        setupBlink()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 애니메이션

    /// 호흡 애니메이션을 시작한다. 마스코트가 살짝 위아래로 움직인다.
    func playBreathAnimation() {
        // spritecat은 idle 프레임 애니메이션으로 대체
        if currentSet.isSpriteSheet {
            playSpriteAnimation(for: .idle)
            return
        }

        let breathUp = SKAction.moveBy(x: 0, y: 2, duration: 1.5)
        breathUp.timingMode = .easeInEaseOut
        let breathDown = SKAction.moveBy(x: 0, y: -2, duration: 1.5)
        breathDown.timingMode = .easeInEaseOut
        let breathSequence = SKAction.sequence([breathUp, breathDown])
        run(SKAction.repeatForever(breathSequence), withKey: "breath")
    }

    /// 상태를 변경하고 해당 애니메이션을 시작한다.
    func setState(_ state: MascotState) {
        guard state != currentState else { return }
        currentState = state

        // 기존 상태 애니메이션 제거 + 회전/틴트 리셋
        removeAction(forKey: "stateAnim")
        removeAction(forKey: "breath")
        removeAction(forKey: "tintAnim")
        removeAction(forKey: "spriteAnim")
        run(SKAction.rotate(toAngle: 0, duration: 0.2))
        run(SKAction.colorize(withColorBlendFactor: 0, duration: 0.2))

        // spritecat: 프레임 기반 애니메이션
        if currentSet.isSpriteSheet {
            playSpriteAnimation(for: state)
            return
        }

        // 코드 마스코트: 기존 SKAction 기반 애니메이션
        if let tintAnim = StateAnimations.tintAnimation(for: state) {
            run(tintAnim, withKey: "tintAnim")
        }

        let transition = StateAnimations.transitionAction(to: state, baseScale: baseScale)
        let stateAnim = StateAnimations.animation(for: state, baseScale: baseScale)
        run(SKAction.sequence([transition, stateAnim]), withKey: "stateAnim")
    }

    /// guard 없이 상태 애니메이션을 강제 적용한다 (마스코트 셋 변경, 전환 복귀 시 사용).
    func forceSetState(_ state: MascotState) {
        currentState = state

        removeAction(forKey: "stateAnim")
        removeAction(forKey: "breath")
        removeAction(forKey: "tintAnim")
        removeAction(forKey: "spriteAnim")
        run(SKAction.rotate(toAngle: 0, duration: 0.2))
        run(SKAction.colorize(withColorBlendFactor: 0, duration: 0.2))

        // 깜빡임 루프가 없으면 재시작
        if action(forKey: "blinkLoop") == nil {
            restartBlinkLoop()
        }

        if currentSet.isSpriteSheet {
            playSpriteAnimation(for: state)
            return
        }

        if let tintAnim = StateAnimations.tintAnimation(for: state) {
            run(tintAnim, withKey: "tintAnim")
        }
        let transition = StateAnimations.transitionAction(to: state, baseScale: baseScale)
        let stateAnim = StateAnimations.animation(for: state, baseScale: baseScale)
        run(SKAction.sequence([transition, stateAnim]), withKey: "stateAnim")
    }

    // MARK: - 스프라이트 시트 애니메이션

    private func playSpriteAnimation(for state: MascotState) {
        guard let frames = spriteFrames?[state], !frames.isEmpty else { return }

        let timePerFrame: TimeInterval
        switch state {
        case .idle:       timePerFrame = 0.25  // 느긋한 수면
        case .working:    timePerFrame = 0.08  // 빠른 타이핑
        case .needsInput: timePerFrame = 0.12  // 손 흔들기
        case .done:       timePerFrame = 0.10  // 신나는 점프
        case .error:      timePerFrame = 0.10  // 혼란
        case .playing:    timePerFrame = 0.15  // 돌아다니기
        }

        let animate = SKAction.animate(with: frames, timePerFrame: timePerFrame)
        run(SKAction.repeatForever(animate), withKey: "spriteAnim")
    }

    // MARK: - 마스코트 셋 교체

    /// 마스코트 셋을 변경한다. 텍스처를 교체하고 UserDefaults에 저장한다.
    func setMascotSet(_ set: MascotSet) {
        guard set != currentSet else { return }
        currentSet = set
        set.save()

        // 스프라이트 시트 프레임 로드/해제
        if set.isSpriteSheet {
            spriteFrames = SpriteSheetLoader.loadFrames()
        } else {
            spriteFrames = nil
        }

        self.texture = set.generateTexture(size: CGSize(width: 28, height: 28))
        self.size = MascotNode.displaySize(for: set)
        print("[MascotNode] 마스코트 변경: \(set.displayName) (\(self.size))")

        // 눈 깜빡임 재설정
        setupBlink()

        // 현재 상태 애니메이션 강제 재적용 (baseScale은 호출 전에 설정되어야 함)
        forceSetState(currentState)
    }

    /// 텍스처만 변경하고 애니메이션은 재적용하지 않는다. 외부에서 스케일 제어 시 사용.
    func setMascotSetWithoutAnimation(_ set: MascotSet) {
        guard set != currentSet else { return }
        currentSet = set
        set.save()

        spriteFrames = nil
        self.texture = set.generateTexture(size: CGSize(width: 28, height: 28))
        self.size = MascotNode.displaySize(for: set)
        setupBlink()
    }

    // MARK: - 눈 깜빡임

    private struct EyeConfig {
        let leftPos: CGPoint
        let rightPos: CGPoint
        let eyeSize: CGSize
        let lidColor: NSColor
    }

    /// 마스코트 셋별 눈 위치와 피부색을 반환한다.
    private func eyeConfig(for set: MascotSet) -> EyeConfig? {
        switch set {
        case .claude:
            // PNG 마스코트 ~47x34, 눈 위치는 비율 기반
            let w = self.size.width
            let h = self.size.height
            return EyeConfig(
                leftPos: CGPoint(x: w * -0.20, y: h * 0.18),
                rightPos: CGPoint(x: w * 0.20, y: h * 0.18),
                eyeSize: CGSize(width: w * 0.16, height: h * 0.20),
                lidColor: NSColor(red: 0.89, green: 0.42, blue: 0.34, alpha: 1.0)
            )
        case .rabbit:
            let s = self.size.width
            return EyeConfig(
                leftPos: CGPoint(x: s * -0.20, y: s * 0.13),
                rightPos: CGPoint(x: s * 0.20, y: s * 0.13),
                eyeSize: CGSize(width: 4, height: 4),
                lidColor: NSColor(red: 0.95, green: 0.90, blue: 0.85, alpha: 1.0)
            )
        case .whiteCat:
            let s = self.size.width
            return EyeConfig(
                leftPos: CGPoint(x: s * -0.20, y: s * 0.13),
                rightPos: CGPoint(x: s * 0.20, y: s * 0.13),
                eyeSize: CGSize(width: 4, height: 4),
                lidColor: NSColor(white: 0.95, alpha: 1.0)
            )
        case .blackCat:
            let s = self.size.width
            return EyeConfig(
                leftPos: CGPoint(x: s * -0.20, y: s * 0.13),
                rightPos: CGPoint(x: s * 0.20, y: s * 0.13),
                eyeSize: CGSize(width: 4, height: 4),
                lidColor: NSColor(white: 0.15, alpha: 1.0)
            )
        case .bichon:
            // bichonImage 눈 위치: (8,18) + (17,18), 크기 3x1, 캔버스 28x28
            let w = self.size.width
            let h = self.size.height
            let leftX = (9.5 / 28.0 - 0.5) * w
            let rightX = (18.5 / 28.0 - 0.5) * w
            let eyeY = (18.5 / 28.0 - 0.5) * h
            return EyeConfig(
                leftPos: CGPoint(x: leftX, y: eyeY),
                rightPos: CGPoint(x: rightX, y: eyeY),
                eyeSize: CGSize(width: w * 4.0 / 28.0, height: h * 2.0 / 28.0),
                lidColor: NSColor(white: 1.0, alpha: 1.0)
            )
        }
    }

    /// 눈 깜빡임 노드를 생성하고 루프를 시작한다.
    private func setupBlink() {
        // 기존 제거
        leftEyelid?.removeFromParent()
        rightEyelid?.removeFromParent()
        removeAction(forKey: "blinkLoop")

        guard let config = eyeConfig(for: currentSet) else { return }

        let left = SKShapeNode(rectOf: config.eyeSize, cornerRadius: 1)
        left.fillColor = config.lidColor
        left.strokeColor = .clear
        left.zPosition = 10
        left.position = config.leftPos
        left.yScale = 0
        addChild(left)
        leftEyelid = left

        let right = SKShapeNode(rectOf: config.eyeSize, cornerRadius: 1)
        right.fillColor = config.lidColor
        right.strokeColor = .clear
        right.zPosition = 10
        right.position = config.rightPos
        right.yScale = 0
        addChild(right)
        rightEyelid = right

        // 깜빡임 루프: 2~5초 간격
        let blink = SKAction.run { [weak self] in
            self?.doBlink()
        }
        let wait = SKAction.wait(forDuration: 3.5, withRange: 3.0)
        run(SKAction.repeatForever(SKAction.sequence([wait, blink])), withKey: "blinkLoop")
    }

    /// 깜빡임 루프만 재시작한다 (eyelid 노드는 유지).
    private func restartBlinkLoop() {
        guard leftEyelid != nil, rightEyelid != nil else { return }
        removeAction(forKey: "blinkLoop")
        let blink = SKAction.run { [weak self] in
            self?.doBlink()
        }
        let wait = SKAction.wait(forDuration: 3.5, withRange: 3.0)
        run(SKAction.repeatForever(SKAction.sequence([wait, blink])), withKey: "blinkLoop")
    }

    /// 한 번 깜빡인다. 가끔 두 번 연속 깜빡임.
    private func doBlink() {
        guard let left = leftEyelid, let right = rightEyelid else { return }

        let close = SKAction.scaleY(to: 1.0, duration: 0.06)
        let hold = SKAction.wait(forDuration: 0.08)
        let open = SKAction.scaleY(to: 0.0, duration: 0.06)
        let single = SKAction.sequence([close, hold, open])

        // 20% 확률로 두 번 깜빡임
        let seq: SKAction
        if Int.random(in: 0..<5) == 0 {
            let pause = SKAction.wait(forDuration: 0.15)
            seq = SKAction.sequence([single, pause, single])
        } else {
            seq = single
        }

        left.run(seq)
        right.run(seq)
    }
}
