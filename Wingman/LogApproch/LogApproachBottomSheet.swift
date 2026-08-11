//
//  LogApproachBottomSheet.swift
//  Wingman
//

import SwiftUI
import PostHog

struct LogApproachBottomSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = LogApproachViewModel()
    @State private var dragOffset: CGFloat = 0
    @State private var showApproachGuide = false

    // Guards the post-success auto-dismiss against multi-fires. Set the first
    // time `viewModel.showSuccess` flips true for this sheet instance; stays
    // true for the rest of the instance's lifetime.
    @State private var hasScheduledDismiss = false

    // Optional approach for editing
    let approachToEdit: ApproachLog?

    init(isPresented: Binding<Bool>, approachToEdit: ApproachLog? = nil) {
        self._isPresented = isPresented
        self.approachToEdit = approachToEdit
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar (thicker and more visible)
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Header with dynamic title
                HStack {
                    Text(viewModel.headerTitle)
                        .font(.manropeMedium(size: 20))
                        .foregroundColor(.wingmanBlack)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        // MARK: - What type of Interaction?
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Text("What type of Interaction ?")
                                    .font(.manropeMedium(size: 16))
                                    .foregroundColor(.wingmanBlack)

                                Spacer()

                                Button(action: {
                                    showApproachGuide = true
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 15))
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(ScalePressStyle())
                                .padding(.trailing, 8)
                            }

                            // Radio buttons for levels
                            VStack(alignment: .leading, spacing: 12) {
                                RadioButton(
                                    title: "Level 1: Social Warm-up",
                                    isSelected: viewModel.selectedLevel == 1,
                                    action: { viewModel.selectLevel(1) }
                                )

                                RadioButton(
                                    title: "Level 2: Extended Conversation",
                                    isSelected: viewModel.selectedLevel == 2,
                                    action: { viewModel.selectLevel(2) }
                                )

                                RadioButton(
                                    title: "Level 3: Indirect Approach",
                                    isSelected: viewModel.selectedLevel == 3,
                                    action: { viewModel.selectLevel(3) }
                                )

                                RadioButton(
                                    title: "Level 4: Direct Approach",
                                    isSelected: viewModel.selectedLevel == 4,
                                    action: { viewModel.selectLevel(4) }
                                )
                            }
                        }

                        // MARK: - Confidence Level Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Confidence Level")
                                    .font(.manropeMedium(size: 16))
                                    .foregroundColor(.wingmanBlack)

                                Spacer()

                                Text("\(Int(viewModel.anxietyLevel))")
                                    .font(.manropeMedium(size: 16))
                                    .foregroundColor(.wingmanBlack)
                            }

                            VStack(spacing: 8) {
                                // Custom Slider
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Track background
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(red: 0.93, green: 0.93, blue: 0.93))
                                            .frame(height: 4)

                                        // Active track
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.wingmanBlack)
                                            .frame(
                                                width: geometry.size.width * CGFloat((viewModel.anxietyLevel - 1) / 9),
                                                height: 4
                                            )

                                        // Thumb
                                        Circle()
                                            .fill(Color.wingmanBlack)
                                            .frame(width: 20, height: 20)
                                            .offset(
                                                x: geometry.size.width * CGFloat((viewModel.anxietyLevel - 1) / 9) - 10
                                            )
                                            .gesture(
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { value in
                                                        let newValue = min(
                                                            max(1, (value.location.x / geometry.size.width) * 9 + 1),
                                                            10
                                                        )
                                                        let rounded = round(newValue)
                                                        if Int(rounded) != Int(viewModel.anxietyLevel) {
                                                            HapticManager.shared.selection()
                                                        }
                                                        viewModel.anxietyLevel = rounded
                                                    }
                                            )
                                    }
                                }
                                .frame(height: 20)

                                // Labels
                                HStack {
                                    Text("1 - very anxious")
                                        .font(.manropeRegular(size: 14))
                                        .foregroundColor(.gray)

                                    Spacer()

                                    Text("10 - very confident")
                                        .font(.manropeRegular(size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                        }

                        // MARK: - Title Section (NOW BOUND TO VIEWMODEL)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.manropeMedium(size: 16))
                                .foregroundColor(.wingmanBlack)

                            TextField("E.g. Approached at Cafe", text: $viewModel.title)
                                .font(.manropeRegular(size: 14))
                                .foregroundColor(.wingmanBlack)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.98, green: 0.98, blue: 0.98))
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color(red: 0.92, green: 0.92, blue: 0.92), lineWidth: 1)
                                )
                        }

                        // MARK: - Notes Section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Notes")
                                    .font(.manropeMedium(size: 16))
                                    .foregroundColor(.wingmanBlack)
                                
                                Spacer()
                                
                                Text("\(viewModel.notes.count)/400")
                                    .font(.manropeRegular(size: 12))
                                    .foregroundColor(viewModel.notes.count > 400 ? .red : .gray)
                            }

                            ZStack(alignment: .topLeading) {
                                if viewModel.notes.isEmpty {
                                    Text("How did you feel? What happened? Anything you noticed or learned")
                                        .font(.manropeRegular(size: 14))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 14)
                                }

                                TextEditor(text: $viewModel.notes)
                                    .font(.manropeRegular(size: 14))
                                    .foregroundColor(.wingmanBlack)
                                    .frame(minHeight: 100)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .onChange(of: viewModel.notes) { newValue in
                                        // Limit to 400 characters
                                        if newValue.count > 400 {
                                            viewModel.notes = String(newValue.prefix(400))
                                        }
                                    }
                            }
                            .background(Color(red: 0.98, green: 0.98, blue: 0.98))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(viewModel.notes.count > 400 ? Color.red : Color(red: 0.92, green: 0.92, blue: 0.92), lineWidth: 1)
                            )
                            
                            // Character limit warning
                            if viewModel.notes.count >= 380 {
                                HStack {
                                    Spacer()
                                    Text(viewModel.notes.count >= 400 ? "Maximum characters reached" : "Approaching character limit")
                                        .font(.manropeRegular(size: 11))
                                        .foregroundColor(viewModel.notes.count >= 400 ? .red : .orange)
                                }
                            }
                        }

                        // MARK: - Save Button
                        Button(action: {
                            HapticManager.shared.tapStrong()

                            // Deliberately ungated — free forever, for
                            // subscribers and non-subscribers alike.
                            //
                            // An approach log is the user's own record of
                            // something they did in the real world, not a
                            // feature we author or serve: it costs us nothing
                            // beyond a row, it's the habit loop the rest of
                            // the app is meant to feed, and it's the only
                            // thing here that becomes *theirs* over time.
                            // Charging to record it read the way a running
                            // app charging to save a run you already went on
                            // would. The edit path was already exempt on
                            // exactly this reasoning ("users keep control of
                            // their historical data"); creation now matches.
                            viewModel.saveApproach()
                            // Auto-dismiss is scheduled in `.onChange(of:
                            // viewModel.showSuccess)` below so that a failed
                            // save leaves the sheet open with the error
                            // message visible, instead of the unconditional
                            // 2.5s dismiss that used to hide it.
                        }) {
                            HStack {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else if viewModel.showSuccess {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(viewModel.isEditMode ? "Updated!" : "Saved!")
                                        .font(.manropeSemiBold(size: 16))
                                        .foregroundColor(.white)
                                } else {
                                    Text(viewModel.saveButtonTitle)
                                        .font(.manropeSemiBold(size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(viewModel.canSave ? Color.wingmanBlack : Color.gray.opacity(0.3))
                            .cornerRadius(5)
                        }
                        .buttonStyle(ScalePressStyle())
                        .disabled(!viewModel.canSave || viewModel.isSaving)

                        // Error message
                        if !viewModel.errorMessage.isEmpty {
                            Text(viewModel.errorMessage)
                                .font(.manropeRegular(size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isPresented = false
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            // Close button pinned to the sheet's top-right corner
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())
            .padding(.top, 20)
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, alignment: .topTrailing)
        }
        .onAppear {
            if let approach = approachToEdit {
                // Setup for editing existing approach
                viewModel.setupForEditing(approach)
            } else {
                // Setup for new approach entry
                viewModel.setupForNewEntry()
            }
        }
        .onChange(of: viewModel.showSuccess) { isSuccess in
            // Only dismiss on successful save. The VM toggles `showSuccess`
            // false again ~2s after it flips true, so gate on the true
            // transition. `hasScheduledDismiss` guards against the false→true
            // transition ever firing twice (e.g. future multi-save flows).
            guard isSuccess, !hasScheduledDismiss else { return }
            hasScheduledDismiss = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isPresented = false
                }
            }
        }
        .transition(.move(edge: .bottom))
        .sheet(isPresented: $showApproachGuide) {
            ApproachLevelGuideSheet()
                .appDynamicTypeCeiling()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
        // Session replay: the most sensitive screen in the app. The title
        // field and notes editor hold free text about real-world encounters
        // with identifiable third parties who have no relationship with us.
        // Global text masking is off, so this mask is what keeps that out of
        // recordings.
        .postHogMask()
        .appDynamicTypeCeiling()
    }
}

// MARK: - Radio Button Component
struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Radio circle
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.wingmanBlack : Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(Color.wingmanBlack)
                            .frame(width: 10, height: 10)
                    }
                }

                Text(title)
                    .font(.manropeRegular(size: 16))
                    .foregroundColor(.wingmanBlack)

                Spacer()
            }
        }
        .buttonStyle(ScalePressStyle())
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true

        var body: some View {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                if isPresented {
                    LogApproachBottomSheet(isPresented: $isPresented, approachToEdit: nil)
                }
            }
        }
    }

    return PreviewWrapper()
}
