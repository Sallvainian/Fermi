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
    
    // Set up method channels for region detection
    setupMethodChannels()
    
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
  
  // MARK: - Method Channels Setup
  
  func setupMethodChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    // Region detection channel
    let regionChannel = FlutterMethodChannel(
      name: "com.academic-tools.fermi/region",
      binaryMessenger: controller.binaryMessenger
    )
    
    regionChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "isInChinaRegion" {
        result(self?.isInChinaRegion() ?? false)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    // CallKit availability channel
    let callKitChannel = FlutterMethodChannel(
      name: "com.academic-tools.fermi/callkit",
      binaryMessenger: controller.binaryMessenger
    )
    
    callKitChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "isCallKitAvailable" {
        result(self?.isCallKitAvailable() ?? false)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // MARK: - Region Check for CallKit
  
  func shouldEnableCallKit() -> Bool {
    return !isInChinaRegion() && isCallKitAvailable()
  }
  
  func isInChinaRegion() -> Bool {
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
    let chinaRegions = ["CN", "CHN", "HK", "MAC", "HKG", "MO", "TW", "TWN"]
    
    if chinaRegions.contains(regionCode.uppercased()) {
      print("China region detected via locale: \(regionCode)")
      return true
    }
    
    // Additional check using time zone
    let timeZone = TimeZone.current.identifier.lowercased()
    let chinaTimeZones = [
      "asia/shanghai", "asia/beijing", "asia/chongqing",
      "asia/harbin", "asia/kashgar", "asia/urumqi",
      "asia/hong_kong", "asia/macau", "asia/taipei"
    ]
    
    for tz in chinaTimeZones {
      if timeZone.contains(tz) {
        print("China region detected via timezone: \(timeZone)")
        return true
      }
    }
    
    // Check if device store is China App Store
    if let storeCountry = Locale.current.regionCode,
       chinaRegions.contains(storeCountry.uppercased()) {
      print("China App Store detected")
      return true
    }
    
    return false
  }
  
  func isCallKitAvailable() -> Bool {
    // Check if CallKit framework is available and not restricted
    if #available(iOS 10.0, *) {
      // Try to create a call controller to see if CallKit is available
      let callController = CXCallController()
      
      // In China, CallKit APIs will be restricted by the system
      // This is a runtime check to see if we can actually use CallKit
      return CXProvider.isSupported()
    }
    
    return false
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
    guard shouldEnableCallKit() else { 
      print("VoIP push token registration skipped - CallKit not available in region")
      return 
    }
    
    if type == .voIP {
      let token = pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined()
      print("VoIP push token: \(token)")
      
      // Send token to Flutter side
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
    }
  }
  
  // Handle incoming VoIP push notification
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
    guard type == .voIP else {
      completion()
      return
    }
    
    // Check if CallKit is allowed
    guard shouldEnableCallKit() else {
      print("VoIP push received but CallKit not available in region - using fallback notification")
      // In China, we should use regular push notifications instead
      // The server should be configured to send regular push instead of VoIP push for China users
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
    guard shouldEnableCallKit() else { 
      print("VoIP push token invalidation ignored - CallKit not available in region")
      return 
    }
    
    if type == .voIP {
      print("VoIP push token invalidated")
    }
  }
}