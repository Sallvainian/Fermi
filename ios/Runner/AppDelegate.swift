import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase BEFORE Flutter
    FirebaseApp.configure()
    
    // Register plugins with the default Flutter engine managed by FlutterAppDelegate
    GeneratedPluginRegistrant.register(with: self)
    
    // Register for remote notifications (standard push notifications only)
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}