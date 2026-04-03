import SpriteKit

/// 선택 가능한 마스코트 셋.
enum MascotSet: String, CaseIterable, Sendable {
    case claude = "claude"              // 클로드 (PNG 이미지)
    case claudeRabbit = "claude_rabbit" // 테라코타 토끼 (코드 생성)
    case cat = "cat"                    // 흰색 고양이 (코드 생성)
    case robot = "robot"                // 로봇 (코드 생성)
    case spritecat = "spritecat"        // 스프라이트 시트 고양이

    var displayName: String {
        switch self {
        case .claude:       return "Claude"
        case .claudeRabbit: return "Claude Rabbit"
        case .cat:          return "White Cat"
        case .robot:        return "Robot"
        case .spritecat:    return "Sprite Cat"
        }
    }

    /// 스프라이트 시트 기반 마스코트인지 여부
    var isSpriteSheet: Bool {
        self == .spritecat
    }

    /// PNG 파일 기반 마스코트인지 여부 (Resources에 {rawValue}.png로 저장)
    /// SKAction 모션이 자동 적용됨
    var isImageBased: Bool {
        imageName != nil
    }

    /// 리소스 PNG 파일명 (nil이면 코드 생성 마스코트)
    var imageName: String? {
        switch self {
        case .claude: return "claude"  // Resources/claude.png
        default: return nil
        }
    }

    // MARK: - 저장/로드

    private static let key = "selectedMascotSet"

    static var saved: MascotSet {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let set = MascotSet(rawValue: raw) else { return .claude }
        return set
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: MascotSet.key)
    }

    // MARK: - 텍스처 생성

    func generateTexture(size: CGSize) -> SKTexture {
        // PNG 파일 기반 마스코트: Resources/{name}.png 로드
        if let name = imageName {
            if let url = Bundle.module.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                let tex = SKTexture(image: image)
                tex.filteringMode = .nearest
                return tex
            }
        }

        switch self {
        case .claude:       return MascotSet.claudeTexture(size: size) // fallback
        case .claudeRabbit: return MascotSet.claudeTexture(size: size)
        case .cat:          return MascotSet.catTexture(size: size)
        case .robot:        return MascotSet.robotTexture(size: size)
        case .spritecat:
            // 스프라이트 시트의 첫 idle 프레임 사용
            if let tex = SpriteSheetLoader.loadStaticTexture() {
                tex.filteringMode = .nearest
                return tex
            }
            return MascotSet.claudeTexture(size: size)  // fallback
        }
    }

    // MARK: - Claude (테라코타 고양이)

    private static func claudeTexture(size: CGSize) -> SKTexture {
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()

            let main = NSColor(red: 0.82, green: 0.52, blue: 0.35, alpha: 1.0)
            let dark = NSColor(red: 0.58, green: 0.35, blue: 0.24, alpha: 1.0)

            main.setFill()
            // 다리
            NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 10, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 15, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 21, y: 0, width: 4, height: 4)).fill()
            // 몸통
            NSBezierPath(rect: NSRect(x: 2, y: 4, width: 24, height: 8)).fill()
            // 팔
            NSBezierPath(rect: NSRect(x: 0, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 25, y: 6, width: 3, height: 4)).fill()
            // 머리
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 26, height: 10)).fill()
            // 귀
            NSBezierPath(rect: NSRect(x: 3, y: 22, width: 5, height: 5)).fill()
            NSBezierPath(rect: NSRect(x: 20, y: 22, width: 5, height: 5)).fill()
            // 눈
            NSColor.black.setFill()
            NSBezierPath(rect: NSRect(x: 7, y: 17, width: 3, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 18, y: 17, width: 3, height: 3)).fill()
            // 코/입
            dark.setFill()
            NSBezierPath(rect: NSRect(x: 10, y: 13, width: 8, height: 4)).fill()

            return true
        }
        return SKTexture(image: image)
    }

    // MARK: - Cat (흰색 고양이)

    private static func catTexture(size: CGSize) -> SKTexture {
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()

            let main = NSColor(white: 0.92, alpha: 1.0)
            let outline = NSColor(white: 0.6, alpha: 1.0)
            let belly = NSColor(white: 0.85, alpha: 1.0)

            main.setFill()
            // 다리
            NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 10, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 15, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 21, y: 0, width: 4, height: 4)).fill()
            // 몸통
            NSBezierPath(rect: NSRect(x: 2, y: 4, width: 24, height: 8)).fill()
            // 팔
            NSBezierPath(rect: NSRect(x: 0, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 25, y: 6, width: 3, height: 4)).fill()
            // 배 (약간 어두운 부분)
            belly.setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 5, width: 12, height: 6)).fill()
            // 머리
            main.setFill()
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 26, height: 10)).fill()
            // 뾰족한 귀
            NSBezierPath(rect: NSRect(x: 2, y: 22, width: 4, height: 6)).fill()
            NSBezierPath(rect: NSRect(x: 22, y: 22, width: 4, height: 6)).fill()
            // 귀 안쪽 (핑크)
            NSColor(red: 1.0, green: 0.7, blue: 0.75, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 3, y: 23, width: 2, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 23, y: 23, width: 2, height: 3)).fill()
            // 눈 (파란색)
            NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 7, y: 17, width: 3, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 18, y: 17, width: 3, height: 3)).fill()
            // 눈동자
            NSColor(white: 0.15, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 17, width: 1, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 17, width: 1, height: 3)).fill()
            // 코 (핑크)
            NSColor(red: 1.0, green: 0.6, blue: 0.65, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 12, y: 14, width: 4, height: 2)).fill()
            // 수염 (밝은 회색)
            NSColor(white: 0.7, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 3, y: 15, width: 6, height: 1)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 15, width: 6, height: 1)).fill()
            // 외곽선 (흰색이 배경과 구분되도록)
            outline.setFill()
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 1, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 26, y: 12, width: 1, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 2, y: 4, width: 1, height: 8)).fill()
            NSBezierPath(rect: NSRect(x: 25, y: 4, width: 1, height: 8)).fill()

            return true
        }
        return SKTexture(image: image)
    }

    // MARK: - Robot

    private static func robotTexture(size: CGSize) -> SKTexture {
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()

            let body = NSColor(white: 0.55, alpha: 1.0)
            let dark = NSColor(white: 0.4, alpha: 1.0)

            body.setFill()
            // 다리
            NSBezierPath(rect: NSRect(x: 6, y: 0, width: 5, height: 5)).fill()
            NSBezierPath(rect: NSRect(x: 17, y: 0, width: 5, height: 5)).fill()
            // 몸통
            NSBezierPath(rect: NSRect(x: 3, y: 5, width: 22, height: 8)).fill()
            // 팔
            NSBezierPath(rect: NSRect(x: 0, y: 6, width: 4, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 24, y: 6, width: 4, height: 3)).fill()
            // 가슴 패널
            dark.setFill()
            NSBezierPath(rect: NSRect(x: 9, y: 6, width: 10, height: 5)).fill()
            // 가슴 표시등
            NSColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 11, y: 7, width: 2, height: 2)).fill()
            NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 15, y: 7, width: 2, height: 2)).fill()
            // 머리
            body.setFill()
            NSBezierPath(rect: NSRect(x: 4, y: 13, width: 20, height: 10)).fill()
            // 안테나
            dark.setFill()
            NSBezierPath(rect: NSRect(x: 13, y: 23, width: 2, height: 4)).fill()
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 12, y: 26, width: 4, height: 2)).fill()
            // 눈 (파란색)
            NSColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 17, width: 4, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 16, y: 17, width: 4, height: 3)).fill()
            // 입
            dark.setFill()
            NSBezierPath(rect: NSRect(x: 10, y: 14, width: 8, height: 2)).fill()

            return true
        }
        return SKTexture(image: image)
    }
}
