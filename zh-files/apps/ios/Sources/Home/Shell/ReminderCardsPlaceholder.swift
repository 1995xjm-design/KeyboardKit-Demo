import SwiftUI

/// 「建设中」占位目标页：destination Provider 返回 nil 时由主页壳 fallback 使用。
/// 诚实空状态：功能未就绪时不展示假数据，只说明功能与状态。
/// F-wind 的提醒真卡就绪后，HomeRemindersCardProvider 直接返回真 destination，本视图仅兜底。
struct HomeCardPlaceholderView: View {
    let kind: HomeCardKind
    var guide: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: kind.icon)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(kind.tint)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text(kind.title)
                        .font(OpenClawType.title3)
                        .foregroundStyle(.primary)

                    Text(String(localized: "This feature is under construction."))
                        .font(OpenClawType.subhead)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let guide {
                        Divider()
                            .padding(.vertical, 4)

                        Label(String(localized: "First-time guide"), systemImage: "questionmark.circle.fill")
                            .font(OpenClawType.footnoteSemiBold)
                            .foregroundStyle(.secondary)

                        Text(guide)
                            .font(OpenClawType.body)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}