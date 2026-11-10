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
//  Button labels have the same problem in the other direction: a fixed
//  height. `labelHeight(_:)` keeps that height for English and turns it into
//  a minimum for a translated app, so a label that needs a second line makes
//  its button taller instead of being clipped.
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

    /// The height of a button label.
    ///
    /// English: `.frame(height: height)`, unchanged. In a translated app
    /// `height` is the least the label may be: a long label first shrinks a
    /// little, then wraps centred, and the button grows around it with some
    /// padding on every side. A label that fits on one line is exactly
    /// `height` tall and looks as it does in English.
    @ViewBuilder
    func labelHeight(
        _ height: CGFloat,
        usesSourceLanguageLayout: Bool = L10n.usesSourceLanguageLayout
    ) -> some View {
        if usesSourceLanguageLayout {
            self.frame(height: height)
        } else {
            self
                .minimumScaleFactor(TranslatedLabel.minimumScaleFactor)
                .multilineTextAlignment(.center)
                .padding(.vertical, TranslatedLabel.verticalPadding)
                .padding(.horizontal, TranslatedLabel.horizontalPadding)
                .frame(minHeight: height)
        }
    }
}

/// Numbers used by `labelHeight(_:)` in a translated app.
nonisolated enum TranslatedLabel {
    /// How far a long label shrinks before it wraps or is cut.
    static let minimumScaleFactor: CGFloat = 0.85
    /// Space kept above and below a label that has grown past its usual height.
    static let verticalPadding: CGFloat = 6
    /// Space kept between a wrapped label and the sides of its button.
    static let horizontalPadding: CGFloat = 12
}
