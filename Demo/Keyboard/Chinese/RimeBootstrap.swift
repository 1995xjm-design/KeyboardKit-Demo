//
//  RimeBootstrap.swift
//  Keyboard
//
//  Rime 首次运行引导：解压内置方案、写入 default.custom.yaml、
//  App Group 可用性检测。主 App 与键盘扩展共用。
//

import Foundation
import HamsterKit

public extension FileManager {
  /// App Group 容器是否可用（未配置 entitlements 时为 false）
  static var isAppGroupAvailable: Bool {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName
    ) != nil
  }

  /// 首次运行：确保沙盒 SharedSupport 与 Rime 目录已就绪（从 bundle 解压内置方案）
  static func ensureSandboxRimeDirectories() throws {
    let marker = sandboxUserDataDirectory.appendingPathComponent(".kkdeployed")
    if FileManager.default.fileExists(atPath: marker.path) { return }
    try initSandboxSharedSupportDirectory(override: true)
    try initSandboxUserDataDirectory(override: true, unzip: true)
    try RimeBootstrap.writeDefaultCustomYamlIfNeeded()
    try "deployed".write(to: marker, atomically: true, encoding: .utf8)
  }
}

/// Rime 启动引导工具
public enum RimeBootstrap {
  /// 写入 default.custom.yaml（启用 t9 九宫格 + rime_ice 雾凇拼音）
  public static func writeDefaultCustomYamlIfNeeded() throws {
    let path = FileManager.sandboxUserDataDefaultCustomYaml.path
    guard !FileManager.default.fileExists(atPath: path) else { return }
    let content = """
    patch:
      schema_list:
        - schema: t9
        - schema: rime_ice
    """
    try content.write(toFile: path, atomically: true, encoding: .utf8)
  }
}
