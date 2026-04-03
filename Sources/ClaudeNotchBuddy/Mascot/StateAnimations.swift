import SpriteKit

/// 상태별 SKAction 애니메이션과 시각 설정을 제공하는 팩토리.
enum StateAnimations {

    /// 상태별 반복 애니메이션을 반환한다.
    static func animation(for state: MascotState) -> SKAction {
        switch state {
        case .idle:
            // 느린 호흡 + 살짝 기울임 (졸린 느낌)
            let up = SKAction.moveBy(x: 0, y: 2, duration: 1.5)
            up.timingMode = .easeInEaseOut
            let down = SKAction.moveBy(x: 0, y: -2, duration: 1.5)
            down.timingMode = .easeInEaseOut
            let tiltRight = SKAction.rotate(toAngle: 0.05, duration: 1.5)
            tiltRight.timingMode = .easeInEaseOut
            let tiltLeft = SKAction.rotate(toAngle: -0.05, duration: 1.5)
            tiltLeft.timingMode = .easeInEaseOut
            let breath = SKAction.repeatForever(SKAction.sequence([up, down]))
            let tilt = SKAction.repeatForever(SKAction.sequence([tiltRight, tiltLeft]))
            return SKAction.group([breath, tilt])

        case .working:
            // 빠른 바운스 + 미세 회전 (열심히 타이핑)
            let up = SKAction.moveBy(x: 0, y: 3, duration: 0.15)
            up.timingMode = .easeOut
            let down = SKAction.moveBy(x: 0, y: -3, duration: 0.15)
            down.timingMode = .easeIn
            let pause = SKAction.wait(forDuration: 0.1)
            let rotL = SKAction.rotate(toAngle: 0.03, duration: 0.15)
            let rotR = SKAction.rotate(toAngle: -0.03, duration: 0.15)
            let bounce = SKAction.repeatForever(SKAction.sequence([up, down, pause]))
            let wiggle = SKAction.repeatForever(SKAction.sequence([rotL, rotR]))
            return SKAction.group([bounce, wiggle])

        case .needsInput:
            // 좌우 흔들기 + scale pulse (주의 끌기)
            let left = SKAction.moveBy(x: -4, y: 0, duration: 0.08)
            left.timingMode = .easeInEaseOut
            let right = SKAction.moveBy(x: 4, y: 0, duration: 0.08)
            right.timingMode = .easeInEaseOut
            let pause = SKAction.wait(forDuration: 0.3)
            let scaleUp = SKAction.scale(to: 1.08, duration: 0.15)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
            let shake = SKAction.sequence([left, right, left, right, pause])
            let pulse = SKAction.sequence([scaleUp, scaleDown, SKAction.wait(forDuration: 0.3)])
            return SKAction.repeatForever(SKAction.group([shake, pulse]))

        case .done:
            // 점프 + 회전 무한 루프 (신나는 축하)
            let jumpUp = SKAction.moveBy(x: 0, y: 6, duration: 0.18)
            jumpUp.timingMode = .easeOut
            let jumpDown = SKAction.moveBy(x: 0, y: -6, duration: 0.18)
            jumpDown.timingMode = .easeIn
            let tiltRight = SKAction.rotate(toAngle: -.pi / 12, duration: 0.18)
            let tiltBack = SKAction.rotate(toAngle: 0, duration: 0.18)
            let jump = SKAction.group([
                SKAction.sequence([jumpUp, jumpDown]),
                SKAction.sequence([tiltRight, tiltBack])
            ])
            let pause = SKAction.wait(forDuration: 0.4)
            return SKAction.repeatForever(SKAction.sequence([jump, pause]))

        case .error:
            // 주기적 shake 무한 루프 (계속 떨림)
            let shake = SKAction.sequence([
                SKAction.moveBy(x: -5, y: 0, duration: 0.04),
                SKAction.moveBy(x: 10, y: 0, duration: 0.04),
                SKAction.moveBy(x: -10, y: 0, duration: 0.04),
                SKAction.moveBy(x: 10, y: 0, duration: 0.04),
                SKAction.moveBy(x: -5, y: 0, duration: 0.04)
            ])
            let shakePhase = SKAction.repeat(shake, count: 3)
            let pause = SKAction.wait(forDuration: 0.8)
            return SKAction.repeatForever(SKAction.sequence([shakePhase, pause]))

        case .playing:
            // 좌우 이동 + 작은 점프 + 살짝 회전 (장난스러운 느낌)
            let moveRight = SKAction.moveBy(x: 12, y: 0, duration: 1.8)
            moveRight.timingMode = .easeInEaseOut
            let moveLeft = SKAction.moveBy(x: -12, y: 0, duration: 1.8)
            moveLeft.timingMode = .easeInEaseOut
            let hop = SKAction.moveBy(x: 0, y: 4, duration: 0.3)
            hop.timingMode = .easeOut
            let hopDown = SKAction.moveBy(x: 0, y: -4, duration: 0.3)
            hopDown.timingMode = .easeIn
            let hopPause = SKAction.wait(forDuration: 0.6)
            let tiltR = SKAction.rotate(toAngle: 0.08, duration: 1.8)
            tiltR.timingMode = .easeInEaseOut
            let tiltL = SKAction.rotate(toAngle: -0.08, duration: 1.8)
            tiltL.timingMode = .easeInEaseOut
            let movement = SKAction.repeatForever(SKAction.sequence([moveRight, moveLeft]))
            let hopping = SKAction.repeatForever(SKAction.sequence([hop, hopDown, hopPause]))
            let tilting = SKAction.repeatForever(SKAction.sequence([tiltR, tiltL]))
            return SKAction.group([movement, hopping, tilting])
        }
    }

    /// 상태별 반짝이는 틴트 애니메이션을 반환한다. nil이면 틴트 없음.
    static func tintAnimation(for state: MascotState) -> SKAction? {
        switch state {
        case .needsInput:
            // 천천히 빨간색 반짝반짝
            let toRed = SKAction.colorize(with: .red, colorBlendFactor: 0.4, duration: 0.6)
            let toNormal = SKAction.colorize(withColorBlendFactor: 0, duration: 0.6)
            return SKAction.repeatForever(SKAction.sequence([toRed, toNormal]))

        case .error:
            // 빠르게 빨간색 반짝반짝
            let toRed = SKAction.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.3)
            let toNormal = SKAction.colorize(withColorBlendFactor: 0, duration: 0.3)
            return SKAction.repeatForever(SKAction.sequence([toRed, toNormal]))

        case .done:
            // 살짝 초록 반짝 (축하 느낌)
            let toGreen = SKAction.colorize(with: NSColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0), colorBlendFactor: 0.2, duration: 0.4)
            let toNormal = SKAction.colorize(withColorBlendFactor: 0, duration: 0.4)
            return SKAction.repeatForever(SKAction.sequence([toGreen, toNormal]))

        default:
            return nil
        }
    }

    /// 상태 진입 시 1회 전환 애니메이션을 반환한다.
    static func transitionAction(to state: MascotState) -> SKAction {
        switch state {
        case .needsInput:
            // 빠른 scale pop
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.1)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.15)
            scaleDown.timingMode = .easeOut
            return SKAction.sequence([scaleUp, scaleDown])

        case .done:
            // 큰 scale pop
            let scaleUp = SKAction.scale(to: 1.3, duration: 0.12)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            return SKAction.sequence([scaleUp, scaleDown])

        case .working:
            let scaleUp = SKAction.scale(to: 1.1, duration: 0.1)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            return SKAction.sequence([scaleUp, scaleDown])

        case .error:
            // 빠른 scale pop (충격)
            let scaleUp = SKAction.scale(to: 1.4, duration: 0.08)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.12)
            scaleDown.timingMode = .easeOut
            return SKAction.sequence([scaleUp, scaleDown])

        case .playing:
            // 살짝 위로 점프하며 시작
            let hop = SKAction.moveBy(x: 0, y: 4, duration: 0.15)
            hop.timingMode = .easeOut
            let land = SKAction.moveBy(x: 0, y: -4, duration: 0.15)
            land.timingMode = .easeIn
            return SKAction.sequence([hop, land])

        default:
            return SKAction.wait(forDuration: 0)
        }
    }
}
