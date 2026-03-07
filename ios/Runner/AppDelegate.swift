import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Overlay view shown during background/inactive to prevent App Switcher preview.
  private var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    showPrivacyOverlay()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    hidePrivacyOverlay()
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    showPrivacyOverlay()
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    guard privacyOverlay == nil, let window = UIApplication.shared.keyWindow else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = UIColor.black
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
