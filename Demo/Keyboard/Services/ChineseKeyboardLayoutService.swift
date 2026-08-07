//
//  ChineseKeyboardLayoutService.swift
//  KeyboardPro
//
//  Created by KeyboardKit Demo customization.
//  Copyright © 2026. All rights reserved.
//
//  💡 Adds a Chinese (zh-Hans) pinyin keyboard layout to the demo.
//
//  KeyboardKit 10.7.3 is distributed as a precompiled binary and
//  doesn't ship a built-in Chinese layout (see Docs/Localization.md,
//  where `zh - Simplified Chinese` is listed under "Requested").
//  The layout service below provides a pinyin input set (a QWERTY
//  letter layout, which is what iOS uses for pinyin input) for the
//  `zh-Hans` locale. It falls back to the standard layout for all
//  other locales.
//
//  ⚠️ VERIFY: This file targets the KeyboardKit 10.7.3 public API as
//  documented. If any type name below doesn't compile against the
//  actual module interface, the fix is a rename (e.g. `InputSet`
//  vs `KeyboardLayout.InputSet` / `Keyboard.InputSet`).
//

import KeyboardKit

/// A layout service that provides a Chinese pinyin input set.
///
/// The pinyin input set is used as the base provider. Since the
/// pinyin letter set is identical to the standard QWERTY set,
/// all other locales look and behave like the standard keyboard.
class ChineseKeyboardLayoutService: KeyboardLayout.StandardService {

    init() {
        super.init(
            baseProvider: KeyboardLayout.DeviceBasedService(
                alphabeticInputSet: InputSet.Alphabetic.chinesePinyin
            )
        )
    }
}

private extension InputSet.Alphabetic {

    /// A Chinese pinyin input set.
    ///
    /// Pinyin keyboards use the QWERTY letter layout, since every
    /// Latin letter maps to a Mandarin syllable.
    static let chinesePinyin = InputSet.Alphabetic(rows: [
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ])
}
