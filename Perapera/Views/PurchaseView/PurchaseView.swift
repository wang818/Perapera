import SwiftUI
import UIKit

struct PlanModel: Identifiable {
    let id: String
    let fallbackTitle: String
    let fallbackPrice: String
    let features: [String]
    let subTitle: String?
    let tag: String?
}

struct PurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var selectedProductID = PurchaseManager.proYearlyProductID

    private let plans: [PlanModel] = [
        PlanModel(
            id: PurchaseManager.proMonthlyProductID,
            fallbackTitle: "purchase_plan_monthly_pro_title".localized(),
            fallbackPrice: "purchase_plan_monthly_pro_price".localized(),
            features: [
                "purchase_feature_transcription_30".localized(),
                "purchase_feature_explanation_unlimited".localized(),
                "purchase_feature_translation_unlimited".localized()
            ],
            subTitle: nil,
            tag: nil
        ),
        PlanModel(
            id: PurchaseManager.proYearlyProductID,
            fallbackTitle: "purchase_plan_yearly_pro_title".localized(),
            fallbackPrice: "purchase_plan_yearly_pro_price".localized(),
            features: [
                "purchase_feature_transcription_30".localized(),
                "purchase_feature_explanation_unlimited".localized(),
                "purchase_feature_translation_unlimited".localized()
            ],
            subTitle: "purchase_plan_yearly_pro_subtitle".localized(),
            tag: "purchase_plan_yearly_pro_tag".localized()
        ),
        PlanModel(
            id: PurchaseManager.basicMonthlyProductID,
            fallbackTitle: "purchase_plan_monthly_basic_title".localized(),
            fallbackPrice: "purchase_plan_monthly_basic_price".localized(),
            features: [
                "purchase_feature_transcription_3".localized(),
                "purchase_feature_explanation_limited".localized(),
                "purchase_feature_translation_unlimited".localized()
            ],
            subTitle: nil,
            tag: nil
        )
    ]

    private var selectedPlan: PlanModel? {
        plans.first(where: { $0.id == selectedProductID })
    }

    private var actionButtonTitle: String {
        if purchaseManager.currentProductID == selectedProductID {
            return "Current Plan"
        }
        return "purchase_subscribe_now".localized()
    }

    private var statusText: String? {
        purchaseManager.lastError ?? purchaseManager.lastMessage
    }

    private var statusColor: Color {
        purchaseManager.lastError == nil ? .green : .red
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let currentPlanName = purchaseManager.currentPlanDisplayName {
                        currentPlanBanner(planName: currentPlanName)
                    }

                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "text.book.closed",
                            color: .green,
                            title: "purchase_feature_grammar_title".localized(),
                            subtitle: "purchase_feature_grammar_subtitle".localized()
                        )
                        FeatureRow(
                            icon: "doc.text",
                            color: .red,
                            title: "purchase_feature_transcription_title".localized(),
                            subtitle: "purchase_feature_transcription_subtitle".localized()
                        )
                        FeatureRow(
                            icon: "globe",
                            color: .purple,
                            title: "purchase_feature_translation_title".localized(),
                            subtitle: "purchase_feature_translation_subtitle".localized()
                        )
                    }
                    .padding(.vertical)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("purchase_choose_plan".localized())
                                .font(.headline)
                            Spacer()
                            if purchaseManager.isLoadingProducts {
                                ProgressView()
                                    .scaleEffect(0.9)
                            }
                        }
                        .padding(.horizontal)

                        ForEach(plans) { plan in
                            PlanRow(
                                plan: plan,
                                productInfo: purchaseManager.productsByID[plan.id],
                                isSelected: selectedProductID == plan.id,
                                isCurrentPlan: purchaseManager.currentProductID == plan.id
                            )
                            .onTapGesture {
                                selectedProductID = plan.id
                                purchaseManager.clearMessages()
                            }
                        }
                    }

                    Button(action: {
                        guard purchaseManager.currentProductID != selectedProductID else { return }
                        purchaseManager.purchase(productID: selectedProductID)
                    }) {
                        HStack(spacing: 8) {
                            if purchaseManager.isProcessingPurchase {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(actionButtonTitle)
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(purchaseManager.currentProductID == selectedProductID ? Color.gray : Color.ex.main)
                        .cornerRadius(12)
                    }
                    .disabled(purchaseManager.isProcessingPurchase || purchaseManager.currentProductID == selectedProductID || selectedPlan == nil)
                    .padding(.horizontal)
                    .padding(.top, 10)

                    if let statusText = statusText {
                        Text(statusText)
                            .font(.footnote)
                            .foregroundColor(statusColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    HStack(spacing: 20) {
                        Button(action: {
                            openURL("https://www.perapera.cc/privacy")
                        }) {
                            Text("purchase_privacy_policy".localized())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Button(action: {
                            openURL("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        }) {
                            Text("purchase_terms_of_use".localized())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Perapera Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        purchaseManager.restorePurchases()
                    }) {
                        Text("purchase_restore".localized())
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .disabled(purchaseManager.isProcessingPurchase)
                }
            }
            .onAppear {
                purchaseManager.loadProducts()
                purchaseManager.refreshEntitlements()
                if selectedPlan == nil, let firstPlan = plans.first {
                    selectedProductID = firstPlan.id
                }
            }
        }
    }

    private func currentPlanBanner(planName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Plan")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(planName)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top, 12)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct PlanRow: View {
    let plan: PlanModel
    let productInfo: StoreProductInfo?
    let isSelected: Bool
    let isCurrentPlan: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                        .foregroundColor(isSelected ? .black : .gray)
                    
                    Text(productInfo?.displayName ?? plan.fallbackTitle)
                        .font(.headline)
                    
                    if let tag = plan.tag {
                        Text(tag)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black)
                            .cornerRadius(4)
                    }

                    if isCurrentPlan {
                        Text("Active")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(productInfo?.displayPrice ?? plan.fallbackPrice)
                            .font(.headline)
                        if let period = productInfo?.subscriptionPeriodText {
                            Text(period)
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if let sub = plan.subTitle {
                            Text(sub)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.leading, 24)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .padding(.horizontal)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
