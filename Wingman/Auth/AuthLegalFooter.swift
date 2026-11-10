//
//  AuthLegalFooter.swift
//  Wingman
//
//  The consent line at the bottom of the sign-in screens:
//  "By continuing you agree to our Terms and Privacy".
//
//  It has two layouts.
//
//  English keeps the original one: a row of four pieces ("By continuing you
//  agree to our" · Terms · "and" · Privacy). It is the code that has always
//  shipped, moved here unchanged.
//
//  A translated app cannot use that row. Four pieces in a fixed order force
//  every language into English word order, and a row cannot wrap, so a longer
//  sentence would be squeezed or cut. A translated app therefore shows ONE
//  sentence, translated as a whole, with the two links inside it. The
//  translator can put the links wherever their grammar needs them, and the
//  sentence wraps onto as many lines as it takes.
//
//  Both layouts open the same two pages in the same in-app browser.
//

import SwiftUI

// MARK: - Copy

enum AuthLegalCopy {

    /// The two pages the line links to.
    ///
    /// The raw value is what stands in the sentence's Markdown —
    /// `[Terms](terms)` — so a translation carries a short fixed word, not a
    /// web address a translator could damage.
    enum Destination: String, CaseIterable {
        case terms
        case privacy

        var url: URL? {
            switch self {
            case .terms:   return URL(string: Constants.TERMS_CONDITIONS_URL)
            case .privacy: return URL(string: Constants.PRIVACY_POLICY_URL)
            }
        }
    }

    /// The English sentence. Also what a broken translation falls back to.
    static let englishSentenceMarkdown = "By continuing you agree to our [Terms](terms) and [Privacy](privacy)"

    /// The sentence in the app's language, as Markdown.
    static var sentenceMarkdown: String {
        String(
            localized: "By continuing you agree to our [Terms](terms) and [Privacy](privacy)",
            comment: "Sign-in legal line, one whole sentence with two links. Translate the words in [square brackets] and move the links wherever the sentence needs them. Keep (terms) and (privacy) exactly as they are."
        )
    }

    /// Which page a tapped link stands for; nil for anything else.
    static func destination(for url: URL) -> Destination? {
        Destination(rawValue: url.absoluteString)
    }

    /// The pages `text` links to, in the order they appear.
    static func destinations(in text: AttributedString) -> [Destination] {
        text.runs.compactMap { run in run.link.flatMap(destination(for:)) }
    }

    /// The sentence ready to show: the links underlined, everything else as
    /// written.
    ///
    /// The line must always offer both pages. If a translation lost a link,
    /// gained an unknown one, or is not valid Markdown, the English sentence
    /// is shown instead — a legal line in the wrong language is better than
    /// one whose links do not work.
    static func sentence(markdown: String = sentenceMarkdown) -> AttributedString {
        if let parsed = parse(markdown) {
            return parsed
        }
        return parse(englishSentenceMarkdown) ?? AttributedString(englishSentenceMarkdown)
    }

    private static func parse(_ markdown: String) -> AttributedString? {
        guard var text = try? AttributedString(markdown: markdown) else { return nil }

        let linkCount = text.runs.filter { $0.link != nil }.count
        let found = destinations(in: text)
        guard found.count == linkCount, Set(found) == Set(Destination.allCases), found.count == Destination.allCases.count else {
            return nil
        }

        for run in text.runs where run.link != nil {
            text[run.range].underlineStyle = .single
        }
        return text
    }
}

// MARK: - View

struct AuthLegalFooter: View {

    /// False shows the original row of four pieces; true shows the single
    /// sentence. Decided by the app's language unless a caller says otherwise.
    var usesSentenceLayout: Bool = !L10n.usesSourceLanguageLayout

    /// Called with the page to open.
    let open: (URL) -> Void

    private static let textColor = Color.wingmanBlack.opacity(0.45)
    private static let linkColor = Color.wingmanBlack.opacity(0.7)

    var body: some View {
        Group {
            if usesSentenceLayout {
                sentence
            } else {
                englishRow
            }
        }
        .font(.manropeRegular(size: 12))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func open(_ destination: AuthLegalCopy.Destination) {
        if let url = destination.url {
            open(url)
        }
    }

    // MARK: English: the original row

    private var englishRow: some View {
        HStack(spacing: 4) {
            Text("By continuing you agree to our")
                .foregroundColor(Self.textColor)

            Button {
                open(.terms)
            } label: {
                Text("Terms")
                    .foregroundColor(Self.linkColor)
                    .underline()
            }
            .buttonStyle(ScalePressStyle())

            Text("and")
                .foregroundColor(Self.textColor)

            Button {
                open(.privacy)
            } label: {
                Text("Privacy")
                    .foregroundColor(Self.linkColor)
                    .underline()
            }
            .buttonStyle(ScalePressStyle())
        }
    }

    // MARK: Translated apps: one sentence

    private var sentence: some View {
        Text(AuthLegalCopy.sentence())
            .foregroundColor(Self.textColor)
            .tint(Self.linkColor)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                guard let destination = AuthLegalCopy.destination(for: url) else { return .discarded }
                open(destination)
                return .handled
            })
    }
}
