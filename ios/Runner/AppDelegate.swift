import Flutter
import UIKit
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
    // Firebase is initialized by Flutter, not native iOS
    // This prevents double initialization issues
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Check if CallKit is allowed in current region
    if shouldEnableCallKit() {
      // Initialize PushKit for VoIP only if not in China
      self.voipRegistration()
    }
    
    // Register for remote notifications
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Region Check for CallKit
  
  func shouldEnableCallKit() -> Bool {
    // Disable CallKit for China region
    let locale = Locale.current
    var regionCode = ""
    
    // Handle iOS version differences for region
    if #available(iOS 16.0, *) {
      regionCode = locale.region?.identifier ?? ""
    } else {
      // For iOS 15 and earlier, use regionCode property
      regionCode = locale.regionCode ?? ""
    }
    
    // Check for China region codes
    let chinaRegions = ["CN", "CHN", "HK", "MAC", "HKG", "MO"]
    
    // Also check carrier info for China Mobile, China Unicom, China Telecom
    if chinaRegions.contains(regionCode.uppercased()) {
      print("CallKit disabled for China region")
      return false
    }
    
    // Additional check using time zone
    let timeZone = TimeZone.current.identifier.lowercased()
    if timeZone.contains("shanghai") || 
       timeZone.contains("beijing") || 
       timeZone.contains("hong_kong") ||
       timeZone.contains("macau") {
      print("CallKit disabled based on timezone")
      return false
    }
    
    return true
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
    guard shouldEnableCallKit() else { return }
    
    if type == .voIP {
      let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
      print("VoIP push token: \(token)")
      
      // Send token to Flutter side
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
    }
  }
  
  // Handle incoming VoIP push notification
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    guard type == .voIP, shouldEnableCallKit() else {
      completion()
      return
    }
    
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
      callData.appName = "Fermi"
      if let photo = callerPhoto {
        callData.avatar = photo
      }
      callData.duration = 30000 // 30 seconds
      callData.extra = data as NSDictionary
      
      // Show incoming call UI
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(callData, fromPushKit: true)
    }
    
    completion()
  }
  
  // Handle invalid VoIP token
  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    guard shouldEnableCallKit() else { return }
    
    if type == .voIP {
      print("VoIP push token invalidated")
    }
  }
}