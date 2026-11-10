//
//  View+TranslatedTextFit.swift
//  Wingman
//
//  Line caps that were sized for English.
//
//  A few texts are capped at one or two lines. The caps were chosen by
//  looking at the English copy, and English fits. A translation is often a
//  third longer, and a cap that English never reaches would cut it off with
//  an ellipsis.
//
//  `lineLimit(_:whenTranslated:shrinkingTo:)` keeps the cap exactly as it is
//  for English and gives a translated app more room: more lines, no cap, or
//  a mild shrink before anything is cut.
//
//  English output must not change, so in the source language this resolves
//  to the same `.lineLimit(n)` the call site had before and a scale factor
//  of 1, which is SwiftUI's default.
//

import SwiftUI

/// How a capped text is allowed to fit.
nonisolated struct TextFit: Equatable {
    /// Maximum number of lines; nil for no cap.
    var lineLimit: Int?
    /// How far the text may shrink before it is cut. 1 means not at all.
    var minimumScaleFactor: CGFloat

    /// The cap for `english`, or the roomier one for a translated app.
    static func resolve(
        english: Int,
        translated: Int?,
        shrinkingTo scale: CGFloat = 1,
        usesSourceLanguageLayout: Bool = L10n.usesSourceLanguageLayout
    ) -> TextFit {
        usesSourceLanguageLayout
            ? TextFit(lineLimit: english, minimumScaleFactor: 1)
            : TextFit(lineLimit: translated, minimumScaleFactor: scale)
    }
}

extension View {

    /// `.lineLimit(english)` for English, unchanged. In a translated app the
    /// cap becomes `translated` (nil for none) and the text may shrink to
    /// `scale` of its size before it is cut.
    func lineLimit(_ english: Int, whenTranslated translated: Int?, shrinkingTo scale: CGFloat = 1) -> some View {
        let fit = TextFit.resolve(english: english, translated: translated, shrinkingTo: scale)
        return self
            .lineLimit(fit.lineLimit)
            .minimumScaleFactor(fit.minimumScaleFactor)
    }
}
