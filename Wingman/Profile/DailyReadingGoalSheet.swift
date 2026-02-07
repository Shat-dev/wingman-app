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
    
    let goals = [2, 6, 10]
    
    init(currentGoal: Int, onSave: @escaping (Int) -> Void) {
        _selectedGoal = State(initialValue: currentGoal)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Goals List
                    VStack(spacing: 0) {
                        ForEach(goals, id: \.self) { goal in
                            Button(action: {
                                selectedGoal = goal
                            }) {
                                HStack {
                                    Text("\(goal) min / day")
                                        .font(.manropeRegular(size: 15))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    if selectedGoal == goal {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 16)
                            }
                            
                            if goal != goals.last {
                                Divider()
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
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
                        .background(Color.black)
                        .cornerRadius(8)
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Daily Reading Goal")
                        .font(.manropeSemiBold(size: 18))
                        .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
    
    private func saveGoal() {
        isSaving = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // TODO: Save to Supabase or UserDefaults
            onSave(selectedGoal)
            UserDefaults.standard.set(selectedGoal, forKey: "daily_reading_goal")
            
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
        print("New goal: \(newGoal) min/day")
    }
}