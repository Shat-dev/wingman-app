//
//  Device+Screen.swift
//  Wingman
//

import SwiftUI
import UIKit

extension UIScreen {
    /// True when the current device has iPhone SE–class height (~667pt or less)
    /// in an upright orientation. Used to gate narrow, targeted layout
    /// adjustments that must NOT affect standard or large iPhones.
    ///
    /// Why the width check: in landscape, a standard iPhone's reported height
    /// drops below 700pt, which would falsely trigger small-phone mode. The
    /// `width < height` guard restricts activation to portrait-oriented small
    /// devices (SE 1/2/3 gen).
    static var isSmallPhone: Bool {
        let size = UIScreen.main.bounds.size
        return size.width < size.height && size.height < 700
    }
}
