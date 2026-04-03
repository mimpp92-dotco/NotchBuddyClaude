import SpriteKit

/// 말풍선 표시 방향.
enum BubbleSide {
    case left   // 마스코트 왼쪽 (꼬리가 오른쪽)
    case right  // 마스코트 오른쪽 (꼬리가 왼쪽)
}

/// 마스코트 옆에 표시되는 말풍선 노드.
/// 둥근 사각형 배경 + 삼각형 꼬리 + 텍스트로 구성된다.
final class BubbleNode: SKNode {

    private let backgroundShape: SKShapeNode
    private let tailShape: SKShapeNode
    private let textLabel: SKLabelNode
    private let side: BubbleSide

    /// 말풍선을 생성한다.
    /// - Parameters:
    ///   - text: 표시할 텍스트
    ///   - side: 마스코트 기준 표시 방향
    ///   - style: 시각 스타일
    init(text: String, side: BubbleSide, style: BubbleStyle = .normal) {
        self.side = side

        // 텍스트 라벨
        textLabel = SKLabelNode(text: text)
        textLabel.fontName = style.fontName
        textLabel.fontSize = style.fontSize
        textLabel.fontColor = style.textColor
        textLabel.horizontalAlignmentMode = .center
        textLabel.verticalAlignmentMode = .center
        textLabel.numberOfLines = 1

        // 텍스트 크기 기반으로 배경 크기 계산
        let textWidth = textLabel.frame.width
        let bubbleWidth = textWidth + style.padding * 2
        let bubbleHeight = style.fontSize + style.padding * 2

        // 둥근 사각형 배경
        let bgRect = CGRect(
            x: -bubbleWidth / 2,
            y: -bubbleHeight / 2,
            width: bubbleWidth,
            height: bubbleHeight
        )
        backgroundShape = SKShapeNode(rect: bgRect, cornerRadius: style.cornerRadius)
        backgroundShape.fillColor = style.backgroundColor
        backgroundShape.strokeColor = .clear
        backgroundShape.lineWidth = 0

        // 삼각형 꼬리 (마스코트 쪽을 가리킴)
        let tailSize: CGFloat = 5
        let tailPath = CGMutablePath()

        switch side {
        case .left:
            // 꼬리가 오른쪽 (마스코트는 오른쪽에 있음)
            tailPath.move(to: CGPoint(x: bubbleWidth / 2, y: 2))
            tailPath.addLine(to: CGPoint(x: bubbleWidth / 2 + tailSize, y: 0))
            tailPath.addLine(to: CGPoint(x: bubbleWidth / 2, y: -2))
            tailPath.closeSubpath()
        case .right:
            // 꼬리가 왼쪽 (마스코트는 왼쪽에 있음)
            tailPath.move(to: CGPoint(x: -bubbleWidth / 2, y: 2))
            tailPath.addLine(to: CGPoint(x: -bubbleWidth / 2 - tailSize, y: 0))
            tailPath.addLine(to: CGPoint(x: -bubbleWidth / 2, y: -2))
            tailPath.closeSubpath()
        }

        tailShape = SKShapeNode(path: tailPath)
        tailShape.fillColor = style.backgroundColor
        tailShape.strokeColor = .clear
        tailShape.lineWidth = 0

        super.init()

        self.name = "bubble"
        self.zPosition = 10

        addChild(backgroundShape)
        addChild(tailShape)
        addChild(textLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 말풍선을 마스코트의 자식 노드로 추가하여 자동으로 따라다닌다.
    /// - Parameters:
    ///   - mascotNode: 마스코트 노드 (자식으로 추가됨)
    ///   - mascotWidth: 마스코트 너비 (간격 계산용)
    ///   - duration: 표시 시간 (초)
    func show(in mascotNode: SKNode, mascotWidth: CGFloat, duration: TimeInterval = 2.5) {
        let offset = mascotWidth / 2 + backgroundShape.frame.width / 2 + 6

        // 마스코트 로컬 좌표 기준 (0,0이 마스코트 중심)
        switch side {
        case .left:
            self.position = CGPoint(x: -offset, y: 4)
        case .right:
            self.position = CGPoint(x: offset, y: 4)
        }

        self.alpha = 0
        self.setScale(0.8)
        mascotNode.addChild(self)

        // 등장 애니메이션
        let fadeIn = SKAction.fadeIn(withDuration: 0.15)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.12)
        scaleUp.timingMode = .easeOut
        let appear = SKAction.group([fadeIn, scaleUp])

        // 유지
        let hold = SKAction.wait(forDuration: duration)

        // 퇴장 애니메이션
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let scaleDown = SKAction.scale(to: 0.9, duration: 0.25)
        let disappear = SKAction.group([fadeOut, scaleDown])

        let remove = SKAction.removeFromParent()

        run(SKAction.sequence([appear, hold, disappear, remove]))
    }

    /// 말풍선을 즉시 제거한다.
    func dismiss() {
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let remove = SKAction.removeFromParent()
        run(SKAction.sequence([fadeOut, remove]))
    }
}
