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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GrapPushSettings") {
      let channel = FlutterMethodChannel(name: "grap/push", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "openSettings" else {
          result(FlutterMethodNotImplemented)
          return
        }
        let settingsURL: String
        if #available(iOS 16.0, *) {
          settingsURL = UIApplication.openNotificationSettingsURLString
        } else {
          settingsURL = UIApplication.openSettingsURLString
        }
        guard let url = URL(string: settingsURL) else {
          result(FlutterError(code: "SETTINGS_UNAVAILABLE", message: "Không mở được cài đặt thông báo.", details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          if opened {
            result(nil)
          } else {
            result(FlutterError(code: "SETTINGS_UNAVAILABLE", message: "Không mở được cài đặt thông báo.", details: nil))
          }
        }
      }
    }
  }
}
