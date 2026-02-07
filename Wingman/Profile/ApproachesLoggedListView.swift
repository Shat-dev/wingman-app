//
//  ApproachesLoggedListView.swift
//  Wingman
//
//  Created by Adnan Khan on 07/02/2026.
//


//
//  ApproachesLoggedListView.swift
//  Wingman
//

import SwiftUI
import Combine

struct ApproachesLoggedListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var approachService = ApproachService.shared
    @State private var searchText = ""
    @State private var isEditMode = false
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var selectedApproach: ApproachLog?
    @State private var showLogApproach = false
    
    // Computed property for filtered approaches
    private var filteredApproaches: [ApproachLog] {
        approachService.searchApproaches(searchText)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            TextField("Search", text: $searchText)
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                        .cornerRadius(8)
                        
                        Button(action: {
                            isEditMode.toggle()
                        }) {
                            Text(isEditMode ? "Done" : "Edit")
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    // Approaches List
                    if approachService.isLoading {
                        VStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding()
                            Text("Loading approaches...")
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else if filteredApproaches.isEmpty {
                        VStack {
                            Spacer()
                            Image(systemName: searchText.isEmpty ? "person.2" : "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.3))
                                .padding(.bottom, 8)
                            
                            Text(searchText.isEmpty ? "No approaches logged yet" : "No approaches found")
                                .font(.manropeSemiBold(size: 16))
                                .foregroundColor(.gray)
                                .padding(.bottom, 4)
                            
                            Text(searchText.isEmpty ? "Start logging your social interactions to see them here" : "Try adjusting your search terms")
                                .font(.manropeRegular(size: 13))
                                .foregroundColor(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(filteredApproaches) { approach in
                                    ApproachLogRow(
                                        approach: approach,
                                        isEditMode: isEditMode,
                                        onEdit: {
                                            selectedApproach = approach
                                            showLogApproach = true
                                        },
                                        onDelete: {
                                            selectedApproach = approach
                                            showingDeleteAlert = true
                                        }
                                    )
                                    
                                    if approach.id != filteredApproaches.last?.id {
                                        Divider()
                                            .padding(.leading, 16)
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    // Error message
                    if !approachService.errorMessage.isEmpty {
                        VStack {
                            Text(approachService.errorMessage)
                                .font(.manropeRegular(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            
                            Button("Retry") {
                                Task {
                                    await approachService.fetchApproaches()
                                }
                            }
                            .font(.manropeSemiBold(size: 14))
                            .foregroundColor(.blue)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        
                        Text("Approaches logged")
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(.black)
                    }
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
            .alert("Delete Approach", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let approach = selectedApproach {
                        Task {
                            let success = await approachService.deleteApproach(approach)
                            if success {
                                // Update local stats after deletion
                                approachService.updateLocalStats()
                            }
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this approach log?")
            }
            .sheet(isPresented: $showLogApproach) {
                if let approach = selectedApproach {
                    LogApproachBottomSheet(
                        isPresented: $showLogApproach,
                        //existingApproach: approach
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
                }
            }
        }
        .onAppear {
            Task {
                await approachService.fetchApproaches()
            }
        }
        .refreshable {
            Task {
                await approachService.fetchApproaches()
            }
        }
    }
}

// MARK: - Approach Log Row
struct ApproachLogRow: View {
    let approach: ApproachLog
    let isEditMode: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(approach.title)
                        .font(.manropeSemiBold(size: 15))
                        .foregroundColor(.black)
                    
                    Text(approach.description)
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(.gray)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 8) {
                        // Level Badge
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text("Level \(approach.level)")
                                .font(.manropeRegular(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .cornerRadius(4)
                        
                        // Anxiety Badge
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text("Anxiety: \(approach.anxietyLevel)")
                                .font(.manropeRegular(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .cornerRadius(4)
                        
                        // Date Badge
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Text(approach.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.manropeRegular(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.95, green: 0.95, blue: 0.95))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                if isEditMode {
                    Menu {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Approach Log Model
struct ApproachLog: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let level: Int
    let anxietyLevel: Int
    let date: Date
}

#Preview {
    ApproachesLoggedListView()
}
