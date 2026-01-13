//
//  SettingsSheet.swift
//  Wingman
//
//  Created by Adnan Khan on 08/01/2026.
//


//
//  SettingsSheet.swift
//  Wingman
//

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalNotifications = true
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Email Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.manropeRegular(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 24)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            Text("shat.myapantsx10@gmail.com")
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                    
                    // MARK: - Daily Reading Goal
                    NavigationLink(destination: Text("Daily Reading Goal")) {
                        HStack {
                            Text("Daily Reading Goal")
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Text("10 min / day")
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.gray)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // MARK: - Goal Notifications Toggle
                    HStack {
                        Text("Goal Notifications")
                            .font(.manropeRegular(size: 15))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Toggle("", isOn: $goalNotifications)
                            .labelsHidden()
                            .tint(.green)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // MARK: - Restore Purchase
                    Button(action: {
                        print("Restore Purchase tapped")
                    }) {
                        Text("Restore Purchase")
                            .font(.manropeRegular(size: 15))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // MARK: - Manage Subscriptions
                    Button(action: {
                        print("Manage Subscriptions tapped")
                    }) {
                        Text("Manage Subscriptions")
                            .font(.manropeRegular(size: 15))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // MARK: - Delete Account
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Text("Delete Account")
                            .font(.manropeRegular(size: 15))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .padding(.horizontal, 24)
                    
                    // MARK: - Version
                    Text("V 6.9.0")
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // MARK: - Log Out Button
                    Button(action: {
                        print("Log Out tapped")
                    }) {
                        Text("Log Out")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Settings")
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
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    print("Account deletion confirmed")
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
}

#Preview {
    SettingsSheet()
}