import SwiftUI

/// 메뉴바 아이콘 아래에 표시되는 팝오버 패널.
/// 좌측: 기능 버튼 (배경 구분), 우측: 세션 목록 또는 설정.
struct PopoverPanel: View {
    @ObservedObject var viewModel: PopoverViewModel

    private let panelWidth: CGFloat = 400
    private let panelHeight: CGFloat = 340

    var body: some View {
        VStack(spacing: 0) {
            // 상태 요약 헤더 (활성 세션이 있을 때만)
            if viewModel.summary.totalActive > 0 {
                StatusHeaderView(summary: viewModel.summary)
                    .frame(height: 28)
                Divider()
            }

            // 메인 콘텐츠
            HStack(spacing: 0) {
                SidebarButtonsView(viewModel: viewModel)

                // 우측: 마스코트 선택 / 설정 / 세션 목록
                if viewModel.isShowingMascotSelector {
                    MascotSelectorView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isShowingSettings {
                    SettingsContentView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    SessionListView(
                        sessions: viewModel.sessions,
                        onSessionClicked: viewModel.onSessionClicked
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Divider()

            // 하단: 버전 + 종료
            HStack(spacing: 0) {
                Text("Claude Notch Buddy v1.0")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "power")
                            .font(.system(size: 9, weight: .semibold))
                        Text(quitText)
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.65))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
        }
        .frame(width: panelWidth, height: panelHeight)
    }

    private var quitText: String {
        switch AppLanguage.saved {
        case .ko: return "종료"
        case .en: return "Quit"
        case .ja: return "終了"
        case .zh: return "退出"
        }
    }
}
