import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var playbackOriginalTitle: String?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerStorageUsage(flutterViewController)
    registerPlaybackWindow(flutterViewController)

    super.awakeFromNib()
  }

  private func registerPlaybackWindow(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "huangguo/playback_window", binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setPlaybackTitle" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.setPlaybackTitle(call.arguments as? String)
      result(nil)
    }
  }

  private func setPlaybackTitle(_ videoTitle: String?) {
    if let videoTitle = videoTitle {
      if playbackOriginalTitle == nil { playbackOriginalTitle = title }
      title = videoTitle.isEmpty ? playbackOriginalTitle ?? title : videoTitle
    } else if let original = playbackOriginalTitle {
      title = original
      playbackOriginalTitle = nil
    }
  }

  private func registerStorageUsage(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "huangguo/storage_usage", binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "read" else {
        result(FlutterMethodNotImplemented)
        return
      }
      Self.readStorageUsage(result)
    }
  }

  private static func readStorageUsage(_ result: FlutterResult) {
    let manager = FileManager.default
    let directories: [FileManager.SearchPathDirectory] = [
      .documentDirectory, .applicationSupportDirectory, .cachesDirectory,
    ]
    // 仅统计本应用的容器，非沙盒构建交由 Dart 读取应用专属目录。
    var usage: [String: Any] = [:]
    if ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil {
      let roots = directories.compactMap {
        manager.urls(for: $0, in: .userDomainMask).first?.path
      }
      usage["appRoots"] = roots + [NSTemporaryDirectory(), Bundle.main.bundlePath]
      usage["includesApplication"] = true
    }
    do {
      let home = URL(fileURLWithPath: NSHomeDirectory())
      let values = try home.resourceValues(forKeys: [
        .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
      ])
      if let total = values.volumeTotalCapacity { usage["totalBytes"] = total }
      if let available = values.volumeAvailableCapacity { usage["availableBytes"] = available }
    } catch {
      NSLog("[MainFlutterWindow.swift] readStorageUsage: 无法读取设备空间: %@", "\(error)")
    }
    result(usage)
  }
}
