//
//  FooterLinksRow.swift
//  Wingman
//
//  The row of three small links under the paywall and the one-time offer:
//  Privacy · Restore · Terms.
//
//  In English the three words are short and sit spread across a row with
//  60pt of padding on each side. That leaves about 280pt on a large phone
//  and 255pt on an iPhone SE. German needs roughly 330pt for the same three
//  links ("Datenschutz", "Wiederherstellen", "Nutzungsbedingungen"), so the
//  English row would squeeze or cut them.
//
//  English keeps the row exactly as it was. A translated app tries, in
//  order, and takes the first that fits:
//
//    1. the same row with the same 60pt padding;
//    2. the same row with 20pt padding;
//    3. the three links stacked, centred.
//
//  With labels as short as the English ones, option 1 fits and looks the
//  same as the English row.
//
//  The three links are passed in, so each screen keeps its own buttons,
//  actions and disabled states.
//

import SwiftUI

struct FooterLinksRow<Leading: View, Center: View, Trailing: View>: View {

    /// False shows the original fixed row; true lets the row adapt. Decided
    /// by the app's language unless a caller says otherwise.
    var adaptsToLongLabels: Bool = !L10n.usesSourceLanguageLayout

    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var center: () -> Center
    @ViewBuilder var trailing: () -> Trailing

    /// The original side padding.
    static var widePadding: CGFloat { 60 }
    /// Side padding when the labels need more room.
    static var narrowPadding: CGFloat { 20 }
    /// The least space kept between two links before giving up on a row.
    static var minimumGap: CGFloat { 16 }

    var body: some View {
        if adaptsToLongLabels {
            ViewThatFits(in: .horizontal) {
                row(minimumGap: Self.minimumGap)
                    .padding(.horizontal, Self.widePadding)
                row(minimumGap: Self.minimumGap)
                    .padding(.horizontal, Self.narrowPadding)
                VStack(spacing: 0) {
                    leading()
                    center()
                    trailing()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Self.narrowPadding)
            }
        } else {
            // The original row. Do not change: English users see this.
            HStack(spacing: 0) {
                leading()
                Spacer()
                center()
                Spacer()
                trailing()
            }
            .padding(.horizontal, Self.widePadding)
        }
    }

    private func row(minimumGap: CGFloat) -> some View {
        HStack(spacing: 0) {
            leading()
            Spacer(minLength: minimumGap)
            center()
            Spacer(minLength: minimumGap)
            trailing()
        }
    }
}
