import SwiftUI
import SpriteKit

/// 팝오버 우측 영역에 표시되는 마스코트 선택 화면.
struct MascotSelectorView: View {
    @ObservedObject var viewModel: PopoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                Text(localizedText("mascot"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.isShowingMascotSelector = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // 마스코트 그리드 (2x2)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MascotSet.allCases, id: \.rawValue) { set in
                    mascotCard(set)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - 마스코트 카드

    private func mascotCard(_ set: MascotSet) -> some View {
        let isSelected = viewModel.currentMascot == set
        return Button(action: {
            viewModel.currentMascot = set
            set.save()
            viewModel.onMascotChanged?(set)
        }) {
            VStack(spacing: 6) {
                // 미리보기 (SpriteKit 텍스처 → NSImage → SwiftUI Image)
                mascotPreview(set)
                    .frame(width: 48, height: 48)

                Text(set.displayName)
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color(red: 0.91, green: 0.49, blue: 0.36) : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color(red: 0.91, green: 0.49, blue: 0.36).opacity(0.12)
                          : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected
                            ? Color(red: 0.91, green: 0.49, blue: 0.36).opacity(0.5)
                            : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 미리보기 이미지

    private func mascotPreview(_ set: MascotSet) -> some View {
        let nsImage = set.generatePreviewImage(size: CGSize(width: 28, height: 28))
        return Image(nsImage: nsImage)
            .interpolation(.none)
            .resizable()
            .frame(width: 48, height: 48)
    }

    // MARK: - 다국어

    private func localizedText(_ key: String) -> String {
        let lang = AppLanguage.saved
        switch key {
        case "mascot":
            switch lang { case .ko: return "마스코트 선택"; case .en: return "Select Mascot"; case .ja: return "マスコット選択"; case .zh: return "选择吉祥物" }
        default: return key
        }
    }
}
