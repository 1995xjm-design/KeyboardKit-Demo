//
//  RimeCandidateBarView.swift
//  Keyboard
//
//  Rime 引擎候选栏：拼写区（t9 拼音）+ 候选字列表。
//

import Combine
import HamsterKit
import SwiftUI

/// Rime 引擎的候选栏（九宫格模式使用）
struct RimeCandidateBarView: View {
  let rime: RimeContext
  let onSelect: (CandidateSuggestion) -> Void

  @State private var candidates: [CandidateSuggestion] = []
  @State private var inputKey = ""
  @State private var cancellables = Set<AnyCancellable>()

  var body: some View {
    HStack(spacing: 8) {
      if !inputKey.isEmpty {
        Text(inputKey)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 8)
          .fixedSize()
      }
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(candidates) { candidate in
            Button {
              onSelect(candidate)
            } label: {
              VStack(spacing: 2) {
                Text(candidate.text)
                  .font(.title3)
                if let subtitle = candidate.subtitle, !subtitle.isEmpty {
                  Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
      }
      Spacer(minLength: 0)
    }
    .frame(height: 38)
    .background(Color(.systemBackground))
    .overlay(alignment: .bottom) { Divider() }
    .onAppear { subscribe() }
  }

  private func subscribe() {
    rime.$suggestions
      .receive(on: DispatchQueue.main)
      .sink { suggestions in
        candidates = suggestions
      }
      .store(in: &cancellables)
    rime.userInputKeyPublished
      .receive(on: DispatchQueue.main)
      .sink { _ in
        Task { @MainActor in
          inputKey = rime.t9UserInputKey
        }
      }
      .store(in: &cancellables)
  }
}
