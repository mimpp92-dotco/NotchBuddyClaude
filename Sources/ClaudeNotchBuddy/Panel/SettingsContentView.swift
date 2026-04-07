import SwiftUI

/// 팝오버 우측 영역에 표시되는 설정 화면.
struct SettingsContentView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                HStack {
                    Text(localizedText("settings"))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.isShowingSettings = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // 크기 선택
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedText("size"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        ForEach(MascotSize.allCases, id: \.rawValue) { size in
                            sizeButton(size)
                        }
                    }
                }

                // 언어 선택
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedText("language"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 2) {
                        ForEach(AppLanguage.allCases, id: \.rawValue) { lang in
                            languageRow(lang)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - 크기 버튼

    private func sizeButton(_ size: MascotSize) -> some View {
        Button(action: {
            viewModel.currentSize = size
            size.save()
            viewModel.onSizeChanged?(size)
        }) {
            Text(size.displayName)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 44, height: 32)
                .foregroundColor(viewModel.currentSize == size ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(viewModel.currentSize == size
                              ? Color(red: 0.91, green: 0.49, blue: 0.36)
                              : Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 언어 행

    private func languageRow(_ lang: AppLanguage) -> some View {
        Button(action: {
            viewModel.currentLanguage = lang
            lang.save()
            viewModel.onLanguageChanged?(lang)
        }) {
            HStack {
                Text(lang.displayName)
                    .font(.system(size: 12))
                Spacer()
                if viewModel.currentLanguage == lang {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.91, green: 0.49, blue: 0.36))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.currentLanguage == lang
                          ? Color(red: 0.91, green: 0.49, blue: 0.36).opacity(0.1)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 다국어

    private func localizedText(_ key: String) -> String {
        let lang = AppLanguage.saved
        switch key {
        case "settings":
            switch lang { case .ko: return "설정"; case .en: return "Settings"; case .ja: return "設定"; case .zh: return "设置" }
        case "size":
            switch lang { case .ko: return "마스코트 크기"; case .en: return "Mascot Size"; case .ja: return "マスコットサイズ"; case .zh: return "吉祥物大小" }
        case "language":
            switch lang { case .ko: return "언어"; case .en: return "Language"; case .ja: return "言語"; case .zh: return "语言" }
        default: return key
        }
    }
}
