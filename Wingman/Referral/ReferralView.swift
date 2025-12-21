//
//  ReferralView.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI

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
                    print("➡️ Referral submitted:", referralCode)
                    authManager.completePaywallFlow()
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(6)
                }

                // ✅ SKIP → COMPLETE PAYWALL FLOW → DASHBOARD
                HStack {
                    Spacer()
                    Button {
                        print("⏭️ Referral skipped")
                        authManager.completePaywallFlow()
                    } label: {
                        Text("Skip")
                            .foregroundColor(.black)
                            .font(.manropeSemiBold(size: 16))
                            .underline()
                    }
                    Spacer()
                }
            }
            .padding(.top, 24)

            Spacer()
        }
        .padding(.horizontal, 24)
        .navigationTitle("Referral code")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ReferralView()
        .environmentObject(AuthManager())
}
