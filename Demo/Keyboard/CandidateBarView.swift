//
//  CandidateBarView.swift
//  Keyboard
//
//  Pinyin candidate bar, ported from LoveKeyboard.
//

import SwiftUI

/// Horizontal candidate bar shown above the keyboard while
/// pinyin composition is active.
struct CandidateBarView: View {

    let pinyin: String
    let candidates: [String]
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            if !pinyin.isEmpty {
                Text(pinyin)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
                    .fixedSize()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(candidates, id: \.self) { candidate in
                        Button {
                            onSelect(candidate)
                        } label: {
                            Text(candidate)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: 38)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
