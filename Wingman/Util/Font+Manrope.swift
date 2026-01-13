//
//  Font+Manrope.swift.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//

import SwiftUI

extension Font {

    static func manropeBold(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Manrope-Bold", size: size, relativeTo: textStyle)
    }

    static func manropeSemiBold(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Manrope-SemiBold", size: size, relativeTo: textStyle)
    }

    static func manropeMedium(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Manrope-Medium", size: size, relativeTo: textStyle)
    }

    static func manropeRegular(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom("Manrope-Regular", size: size, relativeTo: textStyle)
    }
}
