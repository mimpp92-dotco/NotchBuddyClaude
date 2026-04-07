import SwiftUI

/// 팝오버 상단 상태 요약 헤더.
struct StatusHeaderView: View {
    let summary: StatusSummary

    var body: some View {
        HStack(spacing: 8) {
            if summary.totalActive == 0 {
                Text(localizedText("no_sessions"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                if summary.workingCount > 0 {
                    badge(count: summary.workingCount, label: localizedText("working"), color: .blue)
                }
                if summary.needsInputCount > 0 {
                    badge(count: summary.needsInputCount, label: localizedText("needs_input"), color: .orange)
                }
                if summary.doneCount > 0 {
                    badge(count: summary.doneCount, label: localizedText("done"), color: .green)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private func badge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private func localizedText(_ key: String) -> String {
        let lang = AppLanguage.saved
        switch key {
        case "no_sessions":
            switch lang { case .ko: return "활성 세션 없음"; case .en: return "No active sessions"; case .ja: return "アクティブセッションなし"; case .zh: return "无活跃会话" }
        case "working":
            switch lang { case .ko: return "작업중"; case .en: return "Working"; case .ja: return "作業中"; case .zh: return "工作中" }
        case "needs_input":
            switch lang { case .ko: return "확인필요"; case .en: return "Needs input"; case .ja: return "確認必要"; case .zh: return "需确认" }
        case "done":
            switch lang { case .ko: return "완료"; case .en: return "Done"; case .ja: return "完了"; case .zh: return "完成" }
        default: return key
        }
    }
}
