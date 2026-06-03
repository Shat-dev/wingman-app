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
                    
                    // MARK: - Custom Title Row
                    HStack {
                        Image("feather")
                            .font(.system(size: 18))
                            .foregroundColor(.wingmanBlack)
                        Text("Approaches Logged")
                            .font(.manropeSemiBold(size: 20))
                            .foregroundColor(.wingmanBlack)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.wingmanBlack)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Search Bar (only show if 10+ approaches)
                    if approachService.totalCount >= 10 {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            TextField("Search", text: $searchText)
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(.wingmanBlack)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.96))
                        .cornerRadius(5)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    } else {
                        // Add spacing when search bar is hidden to maintain layout
                        Spacer().frame(height: 12)
                    }
                    
                    // Always show divider
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
                            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
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
            .navigationBarHidden(true)
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
                LogApproachBottomSheet(
                    isPresented: $showLogApproach,
                    approachToEdit: selectedApproach
                )
                // SE-only: matches the HomeView presentation — fractional
                // detent lets users shrink the sheet if the editor feels
                // cramped. Standard / Max phones unchanged.
                .presentationDetents(UIScreen.isSmallPhone ? [.fraction(0.9), .large] : [.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
            }
            .onChange(of: showLogApproach) { isShowing in
                if !isShowing {
                    // Clear selectedApproach when sheet is dismissed
                    selectedApproach = nil
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
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: Title + dots menu
            HStack(alignment: .top, spacing: 12) {
                Text(approach.title)
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(.wingmanBlack)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image("dots")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundColor(.wingmanBlack.opacity(0.7))
                        .frame(width: 18, height: 18)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
            }
            
            // Description
            Text(approach.description)
                .font(.manropeRegular(size: 16))
                .foregroundColor(.wingmanBlack)
                .lineSpacing(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
            
            // Info Row: Date • Level • Confidence (right-aligned)
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text(formatDate(approach.date))
                    Spacer()
                    Text("•")
                    Spacer()
                    Text("Level \(approach.level)")
                    Spacer()
                    Text("•")
                }
                .font(.manropeMedium(size: 12))
                .foregroundColor(.gray)
                
                Spacer()
                
                Text("Confidence: \(approach.anxietyLevel)/10")
                    .font(.manropeMedium(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.trailing)
                    .padding(.trailing,5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    // Format date based on how recent it is
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate days difference
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now))
        
        if let days = components.day {
            if days == 0 {
                return "Today"
            } else if days == 1 {
                return "1 day ago"
            } else if days < 7 {
                return "\(days) days ago"
            } else {
                // For older dates, show actual date
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
        }
        
        // Fallback
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
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
