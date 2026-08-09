//
//  ChineseFeatureStrings.swift
//  Keyboard
//
//  Lightweight system-language following for the Chinese
//  feature UI. Shows Chinese labels on Chinese-system
//  devices, English otherwise. Avoids requiring a string
//  catalog resource in the keyboard extension.
//

import Foundation

/// Returns the Chinese label when the system language is
/// Chinese, otherwise the English label.
func LKString(_ zh: String, _ en: String) -> String {
    Locale.current.language.languageCode?.identifier == "zh" ? zh : en
}
