import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "huangguo/storage_usage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
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
    let home = URL(fileURLWithPath: NSHomeDirectory())
    var usage: [String: Any] = [
      "appRoots": [home.path, Bundle.main.bundlePath],
      "includesApplication": true,
    ]
    do {
      let values = try home.resourceValues(forKeys: [
        .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
      ])
      if let total = values.volumeTotalCapacity { usage["totalBytes"] = total }
      if let available = values.volumeAvailableCapacity { usage["availableBytes"] = available }
    } catch {
      NSLog("[AppDelegate.swift] readStorageUsage: 无法读取设备空间: %@", "\(error)")
    }
    result(usage)
  }
}
