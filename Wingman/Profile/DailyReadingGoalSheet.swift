//
//  DailyReadingGoalSheet.swift
//  Wingman
//
//  Created by Adnan Khan on 07/02/2026.
//


//
//  DailyReadingGoalSheet.swift
//  Wingman
//

import SwiftUI

struct DailyReadingGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoal: Int
    @State private var isSaving = false
    @State private var showSuccess = false
    let onSave: (Int) -> Void
    
    let goals = [2, 5, 10]
    
    init(currentGoal: Int, onSave: @escaping (Int) -> Void) {
        _selectedGoal = State(initialValue: currentGoal)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Grabber (small centered gray line)
                    HStack {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 36, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    
                    // MARK: - Custom Title Row
                    HStack {
                        Text("Daily Reading Goal")
                            .font(.manropeMedium(size: 18))
                            .foregroundColor(.wingmanBlack)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.wingmanBlack)
                                .padding(.top, -20)
                                .padding(.trailing, -2)
                                .opacity(0.5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom,30)
                    
                    // Goals List
                    VStack(spacing: 0) {
                        ForEach(goals, id: \.self) { goal in
                            Button(action: {
                                HapticManager.shared.selection()
                                selectedGoal = goal
                            }) {
                                HStack {
                                    Text("\(goal) min / day")
                                        .font(.manropeRegular(size: 16))
                                        .foregroundColor(.wingmanBlack)
                                    
                                    Spacer()
                                    
                                    if selectedGoal == goal {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.wingmanBlack)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                            }
                            
                          
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        HapticManager.shared.mediumImpact()
                        saveGoal()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else if showSuccess {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("Saved!")
                                    .font(.manropeSemiBold(size: 16))
                                    .foregroundColor(.white)
                            } else {
                                Text("Save")
                                    .font(.manropeSemiBold(size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.wingmanBlack)
                        .cornerRadius(8)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func saveGoal() {
        isSaving = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Save to UserDefaults
            onSave(selectedGoal)
            UserDefaults.standard.set(selectedGoal, forKey: "daily_reading_goal")
            
            // Update notifications if they are enabled
            let goalNotificationsEnabled = UserDefaults.standard.bool(forKey: "goal_notifications")
            if goalNotificationsEnabled {
                Task {
                    await NotificationManager.shared.updateDailyReadingGoalNotification(
                        enabled: true,
                        goalMinutes: selectedGoal
                    )
                }
            }
            
            isSaving = false
            showSuccess = true
            
            // Dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        }
    }
}

#Preview {
    DailyReadingGoalSheet(currentGoal: 10) { newGoal in
        log("New goal: \(newGoal) min/day")
    }
}
