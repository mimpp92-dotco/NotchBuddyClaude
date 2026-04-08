import SpriteKit

/// 선택 가능한 마스코트 셋.
enum MascotSet: String, CaseIterable, Sendable {
    case claude = "claude"          // 테라코타 고양이 (기본)
    case rabbit = "rabbit"          // 토끼
    case whiteCat = "white_cat"     // 흰 고양이
    case blackCat = "black_cat"     // 검은 고양이
    case bichon = "bichon"          // 비숑 프리제

    var displayName: String {
        switch self {
        case .claude:   return "Claude"
        case .rabbit:   return "Rabbit"
        case .whiteCat: return "White Cat"
        case .blackCat: return "Black Cat"
        case .bichon:   return "Bichon"
        }
    }

    /// PNG 파일 기반 마스코트인지 여부 (Resources에 {rawValue}.png로 저장)
    var isImageBased: Bool { imageName != nil }

    /// 리소스 PNG 파일명 (nil이면 코드 생성 마스코트)
    var imageName: String? {
        switch self {
        case .claude: return "claude"   // Resources/claude.png
        case .bichon: return "bichon"   // Resources/bichon.png
        default: return nil
        }
    }

    /// 스프라이트 시트 기반 여부
    var isSpriteSheet: Bool { false }

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

    // MARK: - 프리뷰 이미지 (SwiftUI용, SKTexture 변환 없이)

    func generatePreviewImage(size: CGSize) -> NSImage {
        if let name = imageName {
            if let url = ResourceBundle.bundle.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        switch self {
        case .claude:   return MascotSet.claudeImage(size: size)
        case .rabbit:   return MascotSet.rabbitImage(size: size)
        case .whiteCat: return MascotSet.whiteCatImage(size: size)
        case .blackCat: return MascotSet.blackCatImage(size: size)
        case .bichon:   return MascotSet.claudeImage(size: size)  // fallback (PNG 우선)
        }
    }

    // MARK: - 텍스처 생성

    func generateTexture(size: CGSize) -> SKTexture {
        // PNG 파일 기반 마스코트
        if let name = imageName {
            if let url = ResourceBundle.bundle.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                let tex = SKTexture(image: image)
                tex.filteringMode = .nearest
                return tex
            }
        }

        switch self {
        case .claude:   return MascotSet.claudeTexture(size: size)
        case .rabbit:   return MascotSet.rabbitTexture(size: size)
        case .whiteCat: return MascotSet.whiteCatTexture(size: size)
        case .blackCat: return MascotSet.blackCatTexture(size: size)
        case .bichon:   return MascotSet.claudeTexture(size: size)  // fallback (PNG 우선)
        }
    }

    // MARK: - Claude (테라코타 고양이)

    static func claudeImage(size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            let main = NSColor(red: 0.82, green: 0.52, blue: 0.35, alpha: 1.0)
            let dark = NSColor(red: 0.58, green: 0.35, blue: 0.24, alpha: 1.0)
            main.setFill()
            NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 10, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 15, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 21, y: 0, width: 4, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 2, y: 4, width: 24, height: 8)).fill()
            NSBezierPath(rect: NSRect(x: 0, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 25, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 26, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 3, y: 22, width: 5, height: 5)).fill()
            NSBezierPath(rect: NSRect(x: 20, y: 22, width: 5, height: 5)).fill()
            NSColor.black.setFill()
            NSBezierPath(rect: NSRect(x: 7, y: 17, width: 3, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 18, y: 17, width: 3, height: 3)).fill()
            dark.setFill()
            NSBezierPath(rect: NSRect(x: 10, y: 13, width: 8, height: 4)).fill()
            return true
        }
    }

    static func rabbitImage(size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            let body = NSColor(red: 0.95, green: 0.90, blue: 0.85, alpha: 1.0)
            let inner = NSColor(red: 1.0, green: 0.75, blue: 0.8, alpha: 1.0)
            let dark = NSColor(red: 0.6, green: 0.5, blue: 0.45, alpha: 1.0)
            body.setFill()
            // 발 (1칸)
            NSBezierPath(rect: NSRect(x: 5, y: 0, width: 4, height: 2)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 0, width: 4, height: 2)).fill()
            // 몸통
            NSBezierPath(rect: NSRect(x: 3, y: 2, width: 22, height: 10)).fill()
            // 팔
            NSBezierPath(rect: NSRect(x: 1, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 24, y: 6, width: 3, height: 4)).fill()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 5, width: 12, height: 6)).fill()
            body.setFill()
            NSBezierPath(rect: NSRect(x: 2, y: 12, width: 24, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 5, y: 22, width: 4, height: 8)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 22, width: 4, height: 8)).fill()
            inner.setFill()
            NSBezierPath(rect: NSRect(x: 6, y: 23, width: 2, height: 6)).fill()
            NSBezierPath(rect: NSRect(x: 20, y: 23, width: 2, height: 6)).fill()
            NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 7, y: 17, width: 3, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 18, y: 17, width: 3, height: 3)).fill()
            inner.setFill()
            NSBezierPath(rect: NSRect(x: 12, y: 14, width: 4, height: 2)).fill()
            dark.setFill()
            NSBezierPath(rect: NSRect(x: 2, y: 15, width: 6, height: 1)).fill()
            NSBezierPath(rect: NSRect(x: 20, y: 15, width: 6, height: 1)).fill()
            NSColor.white.setFill()
            NSBezierPath(rect: NSRect(x: 24, y: 6, width: 3, height: 3)).fill()
            return true
        }
    }

    static func whiteCatImage(size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            let main = NSColor(white: 0.95, alpha: 1.0)
            let outline = NSColor(white: 0.7, alpha: 1.0)
            main.setFill()
            // 발 (1칸)
            NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 2)).fill()
            NSBezierPath(rect: NSRect(x: 21, y: 0, width: 4, height: 2)).fill()
            // 몸통
            NSBezierPath(rect: NSRect(x: 2, y: 2, width: 24, height: 10)).fill()
            // 팔
            NSBezierPath(rect: NSRect(x: 0, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 25, y: 6, width: 3, height: 4)).fill()
            NSColor(white: 0.88, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 5, width: 12, height: 6)).fill()
            main.setFill()
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 26, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 2, y: 22, width: 4, height: 6)).fill()
            NSBezierPath(rect: NSRect(x: 22, y: 22, width: 4, height: 6)).fill()
            NSColor(red: 1.0, green: 0.7, blue: 0.75, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 3, y: 23, width: 2, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 23, y: 23, width: 2, height: 3)).fill()
            NSColor(red: 0.3, green: 0.5, blue: 0.9, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 7, y: 17, width: 3, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 18, y: 17, width: 3, height: 3)).fill()
            NSColor(white: 0.15, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 17, width: 1, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 17, width: 1, height: 3)).fill()
            NSColor(red: 1.0, green: 0.6, blue: 0.65, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 12, y: 14, width: 4, height: 2)).fill()
            NSColor(white: 0.7, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 3, y: 15, width: 6, height: 1)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 15, width: 6, height: 1)).fill()
            outline.setFill()
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 1, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 26, y: 12, width: 1, height: 10)).fill()
            return true
        }
    }

    static func blackCatImage(size: CGSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill()
            rect.fill()
            let main = NSColor(white: 0.15, alpha: 1.0)
            main.setFill()
            // 발 (1칸)
            NSBezierPath(rect: NSRect(x: 4, y: 0, width: 4, height: 2)).fill()
            NSBezierPath(rect: NSRect(x: 21, y: 0, width: 4, height: 2)).fill()
            // 몸통
            NSBezierPath(rect: NSRect(x: 2, y: 2, width: 24, height: 10)).fill()
            // 팔
            NSBezierPath(rect: NSRect(x: 0, y: 6, width: 3, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: 25, y: 6, width: 3, height: 4)).fill()
            NSColor(white: 0.22, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 5, width: 12, height: 6)).fill()
            main.setFill()
            NSBezierPath(rect: NSRect(x: 1, y: 12, width: 26, height: 10)).fill()
            NSBezierPath(rect: NSRect(x: 2, y: 22, width: 4, height: 6)).fill()
            NSBezierPath(rect: NSRect(x: 22, y: 22, width: 4, height: 6)).fill()
            NSColor(red: 0.6, green: 0.25, blue: 0.3, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 3, y: 23, width: 2, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 23, y: 23, width: 2, height: 3)).fill()
            NSColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 7, y: 17, width: 3, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 18, y: 17, width: 3, height: 3)).fill()
            NSColor(white: 0.05, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 8, y: 17, width: 1, height: 3)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 17, width: 1, height: 3)).fill()
            NSColor(red: 0.45, green: 0.25, blue: 0.28, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 12, y: 14, width: 4, height: 2)).fill()
            NSColor(white: 0.5, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(x: 3, y: 15, width: 6, height: 1)).fill()
            NSBezierPath(rect: NSRect(x: 19, y: 15, width: 6, height: 1)).fill()
            return true
        }
    }

    private static func claudeTexture(size: CGSize) -> SKTexture {
        SKTexture(image: claudeImage(size: size))
    }

    private static func rabbitTexture(size: CGSize) -> SKTexture {
        SKTexture(image: rabbitImage(size: size))
    }

    private static func whiteCatTexture(size: CGSize) -> SKTexture {
        SKTexture(image: whiteCatImage(size: size))
    }

    private static func blackCatTexture(size: CGSize) -> SKTexture {
        SKTexture(image: blackCatImage(size: size))
    }

}
