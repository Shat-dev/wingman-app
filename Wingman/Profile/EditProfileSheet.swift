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
                        Text("Edit Profile")
                            .font(.manropeMedium(size: 18))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6) // slightly reduced since we added grabber above
                    
                    // Avatar Section
                    VStack(spacing: 16) {
                        // Avatar Illustration
                        ZStack {
                            Image("onboard_img_1")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.gray.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .padding(.top, 40)
                        
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.manropeMedium(size: 14))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 24)
                            
                            TextField("Enter your name", text: $name)
                                .font(.manropeMedium(size: 16))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                                .cornerRadius(5)
                                .padding(.horizontal, 24)
                                .opacity(0.5)
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
                        .cornerRadius(5)
                    }
                    .disabled(name.isEmpty || isSaving)
                    .opacity(name.isEmpty ? 0.5 : 1)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
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
