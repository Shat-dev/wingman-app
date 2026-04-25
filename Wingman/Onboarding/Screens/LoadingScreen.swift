//
//  LoadingScreen.swift
//  Wingman
//
//  The final onboarding screen. Shows the dwell title + animated dots for
//  3 seconds, then fires `onComplete`. Also stamps `onboarding_completed`
//  in Supabase user_metadata for authenticated users on appear (anonymous
//  users have their state synced only at signup).
//

import SwiftUI
import Supabase
import Auth

struct LoadingScreen: View {
    let step: OnboardingStep
    let onComplete: () -> Void

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        // check if this exact text needs the smaller font
        let isPersonalizingText = step.title == "Personalizing an experience just for you..."

        VStack(spacing: 12) {
            Spacer()

            // Loading Text (20pt only for the specific string)
            Text(step.title)
                .font(isPersonalizingText ? .manropeSemiBold(size: 20) : .manropeSemiBold(size: 24))
                .foregroundColor(.wingmanBlack)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Loading Dots Animation (dots are below the text)
            LoadingDotsView()
                .padding(.top, 6)

            Spacer()
        }
        .onAppear {
            // Save name to Supabase only if not anonymous
            if !authManager.isAnonymousUser {
                saveUserName()
            }

            // Wait 3 seconds then complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                log("✅ Finished all questions")
                onComplete()
            }
        }
    }

    // MARK: - Save to Supabase (Auth User Metadata)
    private func saveUserName() {
        // Name is no longer collected during onboarding (SIWA/Google already
        // supply it; email-signup users can set one from Profile). This call
        // only stamps onboarding_completed — it must not write display_name,
        // because doing so would overwrite the SIWA/Google-provided name
        // already stored in user_metadata.
        let updatedAt = ISO8601DateFormatter().string(from: Date())

        log("📤 Marking onboarding complete in Supabase")

        Task {
            do {
                let client = SupabaseManager.shared.client

                try await client.auth.update(
                    user: UserAttributes(
                        data: [
                            "onboarding_completed": AnyJSON.bool(true),
                            "updated_at": AnyJSON.string(updatedAt)
                        ]
                    )
                )

                log("✅ User metadata saved successfully")

            } catch {
                log("❌ Error saving user metadata:", error.localizedDescription)
            }
        }
    }
}

#Preview {
    // Shows the static layout. In runtime the onAppear fires a Supabase
    // write (for authenticated users) and a 3s auto-complete timer; in
    // previews the Supabase call fails silently (no session) and the
    // timer runs but has no onboarding flow to advance into.
    LoadingScreen(
        step: extendedOnboardingSteps.last!,  // "Preparing your experience"
        onComplete: {}
    )
    .environmentObject(AuthManager())
}
