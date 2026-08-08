//
//  ChineseKeyboardLayoutService.swift
//  KeyboardPro
//
//  ⚠️ DISABLED (not part of the build)
//
//  This file previously implemented a custom Chinese (zh-Hans)
//  pinyin layout service. It has been REMOVED from the Xcode
//  project because the KeyboardKit 10.7.3 binary's layout-service
//  API differs from what we initially targeted:
//
//    - `KeyboardLayout` is a struct (no `StandardService` /
//      `DeviceBasedService` nested types)
//    - `InputSet` is not a top-level type
//    - `KeyboardServices` has no `layoutService` member
//
//  The zh-Hans locale still works and falls back to the standard
//  QWERTY layout, which is exactly the pinyin layout. Re-enable a
//  custom layout only after confirming the real API from the
//  module interface (KeyboardKit.swiftinterface).
//
//  Do not re-add this file to the project until then.
//

import KeyboardKit
