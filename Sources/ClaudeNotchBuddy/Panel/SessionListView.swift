import SwiftUI

/// 팝오버 우측 세션 목록.
struct SessionListView: View {
    let sessions: [SessionInfo]
    var onSessionClicked: ((SessionInfo) -> Void)?

    var body: some View {
        if sessions.isEmpty {
            VStack {
                Spacer()
                Text(emptyText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sessions, id: \.sessionId) { session in
                        Button(action: {
                            onSessionClicked?(session)
                        }) {
                            SessionRowView(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyText: String {
        switch AppLanguage.saved {
        case .ko: return "활성 세션 없음"
        case .en: return "No active sessions"
        case .ja: return "アクティブセッションなし"
        case .zh: return "无活跃会话"
        }
    }
}
