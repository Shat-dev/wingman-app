//
//  PracticeCopy.swift
//  Wingman
//
//  Copy shared by the scenario list and the scenario detail screen.
//

import Foundation

enum PracticeCopy {

    /// "3 lessons", or "3 lessons required" while the scenario is locked.
    ///
    /// The count is part of the sentence so each language can apply its own
    /// plural rules to it: the singular ("1 lesson") lives in the String
    /// Catalog as a plural variant of these two entries, not in an `if` here.
    /// Before, the noun was chosen in code and " required" was appended,
    /// which only works for languages built like English.
    static func lessonCountLabel(count: Int, isLocked: Bool) -> String {
        isLocked
            ? String(localized: "\(count) lessons required")
            : String(localized: "\(count) lessons")
    }
}
