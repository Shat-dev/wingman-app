//
//  App.swift
//  Wingman
//
//  Created by Adnan Khan on 03/12/2025.
//

import SwiftUI

extension Font {
    struct App {
        // MARK: - Headings
        static var heading: Font {
            Font.custom("Manrope", size: 32)
        }
        
        // MARK: - SubHeadings
        static var subheading: Font {
            Font.custom("Poppins-SemiBold", size: 20)
        }
        
        // MARK: - Body Text
        static var body: Font {
            Font.custom("Poppins-Regular", size: 16)
        }
        
        // MARK: - Small Text / Description
        static var description: Font {
            Font.custom("Poppins-Light", size: 14)
        }
    }
}
