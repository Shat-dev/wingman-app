//
//  EditProfileSheet.swift
//  Wingman
//
//  Created by Adnan Khan on 07/02/2026.
//


//
//  EditProfileSheet.swift
//  Wingman
//

import SwiftUI

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var showSuccess = false
    let onSave: (String) -> Void
    
    init(currentName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: currentName)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Avatar Section
                    VStack(spacing: 16) {
                        // Avatar Illustration
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.05))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        .padding(.top, 40)
                        
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.manropeMedium(size: 13))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                            
                            TextField("Enter your name", text: $name)
                                .font(.manropeRegular(size: 16))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                .cornerRadius(8)
                                .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: {
                        saveProfile()
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
                    .disabled(name.isEmpty || isSaving)
                    .opacity(name.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Edit Profile")
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
    
    private func saveProfile() {
        guard !name.isEmpty else { return }
        
        isSaving = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // TODO: Save to Supabase
            onSave(name)
            
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
    EditProfileSheet(currentName: "Shat") { newName in
        print("New name: \(newName)")
    }
}