//
//  ReferralView.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI
import PostHog

struct ReferralView: View {

    @EnvironmentObject var authManager: AuthManager
    @State private var referralCode = ""

    var body: some View {
        VStack(spacing: 20) {

            VStack(alignment: .leading, spacing: 16) {

                Text("Enter referral code (optional)")
                    .font(.manropeSemiBold(size: 24))

                TextField("Referral code", text: $referralCode)
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(6)

                // ✅ NEXT → COMPLETE PAYWALL FLOW → DASHBOARD
                Button {
                    log("➡️ Referral submitted:", referralCode)
                    // The code itself is user-entered free text and is
                    // deliberately not sent — only its length, which is
                    // enough to tell a real code from a stray keystroke.
                    Analytics.capture(Analytics.Event.referralStepCompleted, [
                        "action": "submitted",
                        "code_length": referralCode.trimmingCharacters(in: .whitespacesAndNewlines).count,
                    ])
                    authManager.completePaywallFlow()
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(referralCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.wingmanBlack.opacity(0.5) : Color.wingmanBlack)
                        .cornerRadius(6)
                }
                .buttonStyle(ScalePressStyle())
                .disabled(referralCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // ✅ SKIP → COMPLETE PAYWALL FLOW → DASHBOARD
                HStack {
                    Spacer()
                    Button {
                        log("⏭️ Referral skipped")
                        // A near-total skip rate is the case for cutting this
                        // screen out of the flow entirely. Today that rate is
                        // simply unknown.
                        Analytics.capture(Analytics.Event.referralStepCompleted, [
                            "action": "skipped",
                            "code_length": 0,
                        ])
                        authManager.completePaywallFlow()
                    } label: {
                        Text("Skip")
                            .foregroundColor(.wingmanBlack)
                            .font(.manropeSemiBold(size: 16))
                            .underline()
                    }
                    .buttonStyle(ScalePressStyle())
                    Spacer()
                }
            }
            .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationBarBackButtonHidden(true)
        .postHogScreenView("Referral")
    }
}

#Preview {
    ReferralView()
        .environmentObject(AuthManager())
}
