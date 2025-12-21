//
//  Font+Manrope.swift.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//

import SwiftUI

extension Font {
    static func manropeBold(size: CGFloat) -> Font {
        .custom("Manrope-Bold", size: size)
    }
    
    static func manropeSemiBold(size: CGFloat) -> Font {
        .custom("Manrope-SemiBold", size: size)
    }
    
    static func manropeMedium(size: CGFloat) -> Font {
        .custom("Manrope-Medium", size: size)
    }

    static func manropeRegular(size: CGFloat) -> Font {
        .custom("Manrope-Regular", size: size)
    }
}
