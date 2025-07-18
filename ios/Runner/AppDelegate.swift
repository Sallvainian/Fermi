import Flutter
import UIKit
import Firebase
import PushKit
import CallKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var voipRegistry: PKPushRegistry?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    
    // Initialize PushKit for VoIP
    self.voipRegistration()
    
    // Register for remote notifications
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - PushKit VoIP Registration
  
  func voipRegistration() {
    voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry?.delegate = self
    voipRegistry?.desiredPushTypes = [.voIP]
  }
}

// MARK: - PKPushRegistryDelegate

extension AppDelegate: PKPushRegistryDelegate {
  
  // Handle updated PushKit token
  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    if type == .voIP {
      let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
      print("VoIP push token: \(token)")
      
      // Send token to Flutter side
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
    }
  }
  
  // Handle incoming VoIP push notification
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    guard type == .voIP else { return }
    
    // Extract call information from payload
    if let data = payload.dictionaryPayload as? [String: Any] {
      let callId = data["callId"] as? String ?? UUID().uuidString
      let callerName = data["callerName"] as? String ?? "Unknown Caller"
      let callerPhoto = data["callerPhotoUrl"] as? String
      let isVideo = data["isVideo"] as? Bool ?? false
      let handle = data["callerId"] as? String ?? ""
      
      // Configure call data
      let callData = flutter_callkit_incoming.Data(
        id: callId,
        nameCaller: callerName,
        handle: handle,
        type: isVideo ? 1 : 0
      )
      
      // Additional configuration
      callData.appName = "Teacher Dashboard"
      callData.avatar = callerPhoto
      callData.duration = 30000 // 30 seconds
      callData.extra = data
      
      // Show incoming call UI
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(callData, fromPushKit: true)
    }
    
    completion()
  }
  
  // Handle invalid VoIP token
  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    if type == .voIP {
      print("VoIP push token invalidated")
    }
  }
}
