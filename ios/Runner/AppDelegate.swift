import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  
  lazy var flutterEngine = FlutterEngine(name: "fermi_flutter_engine")
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is initialized by Flutter, not native iOS
    // This prevents double initialization issues
    
    // Start the Flutter engine
    flutterEngine.run()
    
    GeneratedPluginRegistrant.register(with: self.flutterEngine)
    
    // Register for remote notifications (standard push notifications only)
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: UISceneSession Lifecycle
  
  override func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }
  
  override func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }
}