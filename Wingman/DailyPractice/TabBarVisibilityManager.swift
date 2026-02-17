//
//  TabBarVisibilityManager.swift
//  Wingman
//
//  Created by Assistant
//

import SwiftUI
import Combine

class TabBarVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = true
    
    func hideTabBar() {
        guard isVisible else { return } // Prevent unnecessary animations
        withAnimation(.easeInOut(duration: 0.2)) {
            isVisible = false
        }
    }
    
    func showTabBar() {
        guard !isVisible else { return } // Prevent unnecessary animations
        withAnimation(.easeInOut(duration: 0.2)) {
            isVisible = true
        }
    }
}
