//
//  SafariView.swift
//  Wingman
//
//  Lightweight SwiftUI wrapper around SFSafariViewController so in-app
//  web links (Privacy, Terms, etc.) present as a modal sheet instead of
//  bouncing the user out to the Safari app.
//

import SwiftUI
import SafariServices

/// URL wrapper that conforms to Identifiable so it can drive `.sheet(item:)`.
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

/// SwiftUI-friendly `SFSafariViewController`. Use inside `.sheet(item:)`:
///
///     @State private var webLink: IdentifiableURL?
///     ...
///     .sheet(item: $webLink) { SafariView(url: $0.url) }
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
