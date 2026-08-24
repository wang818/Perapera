import SwiftUI

/// 第三方数据共享授权弹窗（App Store Guideline 5.1.1(i) / 5.1.2(i) 合规）
///
/// 围绕「用户添加视频后」的数据流向，如实披露：
/// 1. 发送什么数据（视频链接、音频、字幕文本、邮箱、内购信息）
/// 2. 发送给谁及用途（RapidAPI/腾讯云下载存储、阿里云语音识别、腾讯混元翻译、自建服务读音、Google 邮件、Apple 内购）
/// 3. 不出售数据、不用于训练 AI
/// 4. 请求用户明确授权
struct AIConsentView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 顶部内容区（可滚动，适配小屏）
            ScrollView {
                VStack(spacing: 0) {
                    // Icon
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.Ex.main)
                        .padding(.top, 48)

                    // Title
                    Text("ai_consent_title".localized())
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)
                        .padding(.horizontal, 24)

                    // 引导语
                    Text("ai_consent_intro".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 24)

                    // 数据流向卡（发送什么 → 发给谁 → 做什么）
                    VStack(alignment: .leading, spacing: 8) {
                        Label("ai_consent_data_title".localized(), systemImage: "arrow.right.arrow.left")
                            .font(.headline)
                        Text("ai_consent_data_body".localized())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                }
            }

            // 底部固定操作区：隐私政策链接 + 同意 / 暂不
            VStack(spacing: 14) {
                Divider()
                    .padding(.bottom, 2)

                // 同意按钮上方：查看完整隐私政策
                Link(destination: AppConstants.privacyPolicyURL) {
                    Text("ai_consent_privacy_link".localized())
                        .font(.subheadline)
                        .underline()
                        .foregroundColor(Color.Ex.main)
                }

                Button(action: {
                    UserManager.shared.setAIDataSharingConsent(true)
                    dismiss()
                }) {
                    Text("ai_consent_agree".localized())
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.Ex.main)
                        .cornerRadius(12)
                }

                Button(action: {
                    dismiss()
                }) {
                    Text("ai_consent_disagree".localized())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }
}
