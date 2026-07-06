//
//  PurchaseView.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import SwiftUI

struct PlanModel: Identifiable {
    let id = UUID()
    let title: String
    let price: String
    let features: [String]
    let subTitle: String?
    let tag: String?
}
struct PurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlanIndex = 1 // Default to Yearly
    
    let plans: [PlanModel] = [
        PlanModel(
            title: "purchase_plan_monthly_pro_title".localized(),
            price: "purchase_plan_monthly_pro_price".localized(),
            features: [
                "purchase_feature_transcription_30".localized(),
                "purchase_feature_explanation_unlimited".localized(),
                "purchase_feature_translation_unlimited".localized()
            ],
            subTitle: nil,
            tag: nil
        ),
        PlanModel(
            title: "purchase_plan_yearly_pro_title".localized(),
            price: "purchase_plan_yearly_pro_price".localized(),
            features: [
                "purchase_feature_transcription_30".localized(),
                "purchase_feature_explanation_unlimited".localized(),
                "purchase_feature_translation_unlimited".localized()
            ],
            subTitle: "purchase_plan_yearly_pro_subtitle".localized(),
            tag: "purchase_plan_yearly_pro_tag".localized()
        ),
        PlanModel(
            title: "purchase_plan_monthly_basic_title".localized(),
            price: "purchase_plan_monthly_basic_price".localized(),
            features: [
                "purchase_feature_transcription_3".localized(),
                "purchase_feature_explanation_limited".localized(),
                "purchase_feature_translation_unlimited".localized()
            ],
            subTitle: nil,
            tag: nil
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
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
                        Text("purchase_choose_plan".localized())
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(0..<plans.count, id: \.self) { index in
                            PlanRow(plan: plans[index], isSelected: selectedPlanIndex == index)
                                .onTapGesture {
                                    selectedPlanIndex = index
                                }
                        }
                    }

                    Button(action: {
                        // Purchase action
                    }) {
                        Text("purchase_subscribe_now".localized())
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.ex.main)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    HStack(spacing: 20) {
                        Button(action: {}) {
                            Text("purchase_privacy_policy".localized())
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Button(action: {}) {
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
                        // Restore purchase action
                    }) {
                        Text("purchase_restore".localized())
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
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
    let isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                        .foregroundColor(isSelected ? .black : .gray)
                    
                    Text(plan.title)
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
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(plan.price)
                            .font(.headline)
                        if let sub = plan.subTitle {
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
