import AppKit

/// 말풍선의 시각적 스타일 정의.
struct BubbleStyle {
    let backgroundColor: NSColor
    let textColor: NSColor
    let fontName: String
    let fontSize: CGFloat
    let cornerRadius: CGFloat
    let padding: CGFloat

    /// 기본 스타일 (검은 반투명)
    static let normal = BubbleStyle(
        backgroundColor: NSColor(white: 0.12, alpha: 0.85),
        textColor: NSColor(white: 0.9, alpha: 1.0),
        fontName: "Menlo-Bold",
        fontSize: 9,
        cornerRadius: 5,
        padding: 5
    )

    /// 경고 스타일 (빨간 반투명) — error, needsInput
    static let alert = BubbleStyle(
        backgroundColor: NSColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 0.85),
        textColor: NSColor(red: 1.0, green: 0.85, blue: 0.85, alpha: 1.0),
        fontName: "Menlo-Bold",
        fontSize: 9,
        cornerRadius: 5,
        padding: 5
    )

    /// 성공 스타일 (초록 반투명) — done
    static let success = BubbleStyle(
        backgroundColor: NSColor(red: 0.08, green: 0.3, blue: 0.12, alpha: 0.85),
        textColor: NSColor(red: 0.7, green: 1.0, blue: 0.75, alpha: 1.0),
        fontName: "Menlo-Bold",
        fontSize: 9,
        cornerRadius: 5,
        padding: 5
    )
}
