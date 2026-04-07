import SwiftUI

/// 세션 목록의 개별 행.
struct SessionRowView: View {
    let session: SessionInfo
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // 상태 닷
            Circle()
                .fill(stateColor)
                .frame(width: 6, height: 6)

            // 앱 아이콘
            appIconView
                .frame(width: 18, height: 18)

            // 세션 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(session.folderName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(session.lastEventText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
    }

    // MARK: - 앱 아이콘

    @ViewBuilder
    private var appIconView: some View {
        if let bundleId = session.terminalApp.bundleId,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let nsImage = NSWorkspace.shared.icon(forFile: appURL.path)
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: session.terminalApp.systemIconName)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 상태 색상

    private var stateColor: Color {
        switch session.state {
        case .working:    return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .needsInput: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .error:      return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .done:       return Color(red: 0.3, green: 0.9, blue: 0.4)
        case .playing:    return Color(red: 0.6, green: 0.4, blue: 0.9)
        case .idle:       return Color.gray
        }
    }
}
