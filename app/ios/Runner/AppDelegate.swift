import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String
    guard let apiKey,
          !apiKey.isEmpty,
          !apiKey.hasPrefix("$("),
          !apiKey.contains("YOUR_") else {
      fatalError(
        "Missing GOOGLE_MAPS_API_KEY. Copy ios/Flutter/Secrets.xcconfig.example " +
        "to Secrets.xcconfig and add the restricted iOS key."
      )
    }
    GMSServices.provideAPIKey(apiKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
