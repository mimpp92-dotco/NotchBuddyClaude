import SwiftUI

/// 팝오버 좌측 기능 버튼 영역.
/// 반투명 배경으로 우측 콘텐츠 영역과 시각적 구분.
struct SidebarButtonsView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        VStack(spacing: 8) {
            sidebarButton(icon: "theatermasks", label: localizedText("mascot"),
                          active: viewModel.isShowingMascotSelector) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.isShowingMascotSelector.toggle()
                    if viewModel.isShowingMascotSelector { viewModel.isShowingSettings = false }
                }
            }

            sidebarButton(icon: "gearshape", label: localizedText("settings"),
                          active: viewModel.isShowingSettings) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    viewModel.isShowingSettings.toggle()
                    if viewModel.isShowingSettings { viewModel.isShowingMascotSelector = false }
                }
            }

            Spacer()
        }
        .frame(width: 64)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - 버튼 컴포넌트

    private func sidebarButton(
        icon: String,
        label: String,
        disabled: Bool = false,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text(label)
                    .font(.system(size: 9))
            }
            .frame(width: 56, height: 52)
            .foregroundColor(
                disabled ? .secondary.opacity(0.4)
                : active ? Color(red: 0.91, green: 0.49, blue: 0.36)
                : .primary
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(active ? Color(red: 0.91, green: 0.49, blue: 0.36).opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - 다국어

    private func localizedText(_ key: String) -> String {
        let lang = AppLanguage.saved
        switch key {
        case "mascot":
            switch lang { case .ko: return "마스코트"; case .en: return "Mascot"; case .ja: return "マスコット"; case .zh: return "吉祥物" }
        case "settings":
            switch lang { case .ko: return "설정"; case .en: return "Settings"; case .ja: return "設定"; case .zh: return "设置" }
        default: return key
        }
    }
}
