import AppKit

/// 마스코트 크기 단계.
enum MascotSize: String, CaseIterable {
    case s, m, l

    /// 마스코트 스케일 팩터
    var scale: CGFloat {
        switch self {
        case .s: return 1.0
        case .m: return 1.4
        case .l: return 1.9
        }
    }

    /// 그림자 크기
    var shadowSize: CGSize {
        switch self {
        case .s: return CGSize(width: 30, height: 10)
        case .m: return CGSize(width: 42, height: 14)
        case .l: return CGSize(width: 56, height: 18)
        }
    }

    /// 말풍선 폰트 크기 (차이가 뚜렷하도록)
    var bubbleFontSize: CGFloat {
        switch self {
        case .s: return 9
        case .m: return 12
        case .l: return 15
        }
    }

    /// 말풍선 패딩
    var bubblePadding: CGFloat {
        switch self {
        case .s: return 5
        case .m: return 7
        case .l: return 9
        }
    }

    /// 표시 이름
    var displayName: String {
        switch self {
        case .s: return "S"
        case .m: return "M"
        case .l: return "L"
        }
    }

    /// UserDefaults 저장
    func save() {
        UserDefaults.standard.set(rawValue, forKey: "mascotSize")
    }

    /// UserDefaults 로드 (기본 S)
    static var saved: MascotSize {
        guard let raw = UserDefaults.standard.string(forKey: "mascotSize"),
              let size = MascotSize(rawValue: raw) else { return .s }
        return size
    }
}

/// 말풍선의 시각적 스타일 정의.
struct BubbleStyle {
    let backgroundColor: NSColor
    let textColor: NSColor
    let fontName: String
    let fontSize: CGFloat
    let cornerRadius: CGFloat
    let padding: CGFloat

    /// 기본 스타일 (어두운 반투명 — 투명 배경 위 가시성 확보)
    static let normal = BubbleStyle(
        backgroundColor: NSColor(white: 0.15, alpha: 0.92),
        textColor: NSColor(white: 0.95, alpha: 1.0),
        fontName: "Menlo-Bold",
        fontSize: 9,
        cornerRadius: 5,
        padding: 5
    )

    /// 경고 스타일 (빨간 반투명) — error, needsInput
    static let alert = BubbleStyle(
        backgroundColor: NSColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 0.92),
        textColor: NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0),
        fontName: "Menlo-Bold",
        fontSize: 9,
        cornerRadius: 5,
        padding: 5
    )

    /// 성공 스타일 (초록 반투명) — done
    static let success = BubbleStyle(
        backgroundColor: NSColor(red: 0.08, green: 0.3, blue: 0.12, alpha: 0.92),
        textColor: NSColor(red: 0.7, green: 1.0, blue: 0.75, alpha: 1.0),
        fontName: "Menlo-Bold",
        fontSize: 9,
        cornerRadius: 5,
        padding: 5
    )

    /// 마스코트 크기에 맞게 스케일된 스타일을 반환한다.
    func scaled(for size: MascotSize) -> BubbleStyle {
        BubbleStyle(
            backgroundColor: backgroundColor,
            textColor: textColor,
            fontName: fontName,
            fontSize: size.bubbleFontSize,
            cornerRadius: cornerRadius,
            padding: size.bubblePadding
        )
    }
}
