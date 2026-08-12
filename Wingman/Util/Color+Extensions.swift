//
//  Color+Extensions.swift
//  Wingman
//
//  Created by Adnan Khan on 02/03/2026.
//

import SwiftUI
import UIKit

extension UIColor {
    /// Soft black (#1A1A1A). UIKit-side counterpart of `Color.wingmanBlack`.
    /// Used where UIKit APIs (UILabel.textColor, NSAttributedString, etc.) need a UIColor.
    static let wingmanBlack = UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)
}

extension Color {
    // MARK: - Hex Color Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Wingman Brand Colors
    static let wingmanBlack = Color(hex: "#1A1A1A")
    static let wingmanWhiteFF = Color(hex: "#FFFFFF")
    
    // MARK: - Custom Theme Colors
    static let customGreen = Color(red: 0.243, green: 0.561, blue: 0.416) // #3E8F6A
    static let customRed = Color(red: 0.788, green: 0.349, blue: 0.298) // #C9594C

    // MARK: - Stat accents
    //
    // Lifted verbatim from the onboarding growth chart
    // (GrowthChartView.swift:178-180), so this is not a new palette — it is the
    // one the app already ships, reused somewhere it can do more work.
    //
    // Used ONLY to distinguish the three Profile stat categories from each
    // other. Progress itself stays `wingmanBlack` everywhere, on Profile and on
    // the completion screen alike, so a filling bar always means the same thing
    // and colour never competes with it.
    static let accentGreen  = Color(hex: "#2FA96B")
    static let accentClay   = Color(hex: "#D9673F")
    static let accentIndigo = Color(hex: "#5B6CF0")
    static let customDark = Color(red: 0.102, green: 0.102, blue: 0.102) // #1A1A1A
    static let customLightGreen = Color(red: 0.855, green: 0.941, blue: 0.902) // #DAF0E6
    static let customLightRed = Color(red: 0.957, green: 0.871, blue: 0.859) // #F4DEDB
    static let customLightGray = Color(red: 0.953, green: 0.953, blue: 0.953) // #F3F3F3
    static let customCorrectGreen = Color(red: 0.2, green: 0.6, blue: 0.4) // #339966
    static let customIncorrectRed = Color(red: 0.8, green: 0.302, blue: 0.302) // #CC4D4D
    static let customExplanationGreen = Color(red: 0.902, green: 0.969, blue: 0.941) // #E6F7F0
    static let customExplanationRed = Color(red: 1.0, green: 0.929, blue: 0.929) // #FFEDED
}
