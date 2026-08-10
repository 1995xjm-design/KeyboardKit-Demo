//
//  NineGridView.swift
//  Keyboard
//
//  中文九宫格键盘（仿 Hamster 原版 4x4 布局）+ 数字九宫格页。
//  按键动作全部经由 Rime 引擎处理，与 Hamster 输入路由一致。
//

import HamsterKit
import KeyboardKit
import RimeKit
import SwiftUI

/// 九宫格页面
enum NineGridPage {
  case t9
  case numeric
}

/// 中文九宫格键盘
struct NineGridView: View {
  let rime: RimeContext
  let controller: KeyboardInputViewController
  var onShowSymbols: () -> Void
  var onToggleMode: () -> Void

  @State private var page: NineGridPage = .t9

  var body: some View {
    VStack(spacing: 0) {
      switch page {
      case .t9: t9Page
      case .numeric: numericPage
      }
    }
    .frame(maxHeight: .infinity)
  }
}

// MARK: - T9 页

private extension NineGridView {
  var t9Page: some View {
    VStack(spacing: 0) {
      keyRow(["@/.", "ABC", "DEF"], trailing: .backspace)
      keyRow(["GHI", "JKL", "MNO"], trailing: .clean)
      keyRow(["PQRS", "TUV", "WXYZ"], trailing: .returnKey)
      bottomRow
    }
  }

  var bottomRow: some View {
    HStack(spacing: 6) {
      key(title: "符号", isFunction: true) { onShowSymbols() }
      key(title: "123", isFunction: true) { page = .numeric }
      key(title: "空格", isFunction: false) { handleSpace() }
        .frame(maxWidth: .infinity)
      key(title: "中/英", isFunction: true) { onToggleMode() }
    }
    .padding(3)
  }

  func keyRow(_ titles: [String], trailing: NineKey) -> some View {
    HStack(spacing: 6) {
      ForEach(titles, id: \.self) { title in
        key(title: title) { handleT9Key(title) }
      }
      trailingKey(trailing)
    }
    .padding(3)
    .frame(maxHeight: .infinity)
  }

  @ViewBuilder
  func trailingKey(_ nineKey: NineKey) -> some View {
    switch nineKey {
    case .backspace:
      key(title: "⌫", isFunction: true) { handleBackspace() }
    case .clean:
      key(title: "清空", isFunction: true) { handleClean() }
    case .returnKey:
      key(title: "↩︎", isFunction: true) { handleReturn() }
    default:
      EmptyView()
    }
  }

  func handleT9Key(_ title: String) {
    let char: String
    switch title {
    case "@/.": char = "@"
    case "ABC": char = "2"
    case "DEF": char = "3"
    case "GHI": char = "4"
    case "JKL": char = "5"
    case "MNO": char = "6"
    case "PQRS": char = "7"
    case "TUV": char = "8"
    case "WXYZ": char = "9"
    default: char = title
    }
    guard rime.tryHandleInputText(char) else {
      controller.textDocumentProxy.insertText(char)
      return
    }
  }

  func handleBackspace() {
    if rime.userInputKey.isEmpty {
      controller.textDocumentProxy.deleteBackward()
    } else {
      rime.deleteBackward()
    }
  }

  func handleClean() {
    rime.reset()
  }

  func handleSpace() {
    if rime.userInputKey.isEmpty {
      controller.textDocumentProxy.insertText(" ")
    } else {
      _ = rime.tryHandleInputCode(XK_space)
    }
  }

  func handleReturn() {
    guard rime.tryHandleInputCode(XK_Return) else {
      controller.textDocumentProxy.insertText("\n")
      return
    }
  }
}

// MARK: - 数字九宫格页

private extension NineGridView {
  var numericPage: some View {
    VStack(spacing: 0) {
      keyRow(["1", "2", "3"], trailing: .backspace)
      keyRow(["4", "5", "6"], trailing: .clean)
      keyRow(["7", "8", "9"], trailing: .returnKey)
      numericBottomRow
    }
  }

  var numericBottomRow: some View {
    HStack(spacing: 6) {
      key(title: "符号", isFunction: true) { onShowSymbols() }
      key(title: "0") { handleDigit("0") }
      key(title: "空格", isFunction: false) { handleSpace() }
        .frame(maxWidth: .infinity)
      key(title: "九宫", isFunction: true) { page = .t9 }
    }
    .padding(3)
  }

  func handleDigit(_ digit: String) {
    if rime.userInputKey.isEmpty {
      controller.textDocumentProxy.insertText(digit)
    } else {
      _ = rime.tryHandleInputText(digit)
    }
  }
}

// MARK: - 通用按键视图

private extension NineGridView {
  func key(
    title: String,
    isFunction: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(isFunction ? .subheadline.weight(.medium) : .title2.weight(.medium))
        .foregroundStyle(isFunction ? Color.secondary : Color.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isFunction ? Color(.systemGray5) : Color(.secondarySystemBackground))
        )
    }
    .buttonStyle(.plain)
  }
}

/// 九宫格右侧功能键类型
private enum NineKey {
  case backspace
  case clean
  case returnKey
}
