import UserNotifications
import UIKit

class NotificationService: NSObject {
    static let shared = NotificationService()
    
    private var fcmToken: String?
    private var apnsToken: Data?
    
    override init() {
        super.init()
        setupNotificationCenter()
    }
    
    private func setupNotificationCenter() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("NotificationService: Permission granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("NotificationService: Permission denied")
            }
            
            if let error = error {
                print("NotificationService: Error requesting permission: \(error)")
            }
        }
    }
    
    func configureNotificationCategories() {
        // Define notification categories for different types of notifications
        let orderCategory = UNNotificationCategory(
            identifier: "ORDER_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let deliveryCategory = UNNotificationCategory(
            identifier: "DELIVERY_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([orderCategory, deliveryCategory])
    }
    
    func setAPNSToken(_ deviceToken: Data) {
        apnsToken = deviceToken
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("NotificationService: APNS token: \(tokenString)")
        
        // Here you would normally send this token to your FCM server
        // For now, we'll store it locally
        UserDefaults.standard.set(tokenString, forKey: "apns_token")
    }
    
    func setFCMToken(_ token: String) {
        fcmToken = token
        print("NotificationService: FCM token: \(token)")
        UserDefaults.standard.set(token, forKey: "fcm_token")
        
        // Send token to your server if needed
        sendTokenToServer(token: token)
    }
    
    private func sendTokenToServer(token: String) {
        // Implementation to send FCM token to your server
        guard let url = URL(string: AppConfig.shared.fcmTokenAPIEndpoint) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let tokenData = ["fcm_token": token, "platform": "ios"]
        
        // Add cookies to request
        CookieManager.shared.addCookiesToRequest(&request, for: url)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: tokenData)
        } catch {
            print("NotificationService: Error serializing token data: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("NotificationService: Error sending token: \(error)")
            } else {
                print("NotificationService: Token sent successfully")
            }
        }.resume()
    }
    
    func showLocalNotification(title: String, body: String, sound: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // Set custom sound if provided
        if let soundName = sound, !soundName.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }
        
        // Create request
        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        // Add notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationService: Error showing notification: \(error)")
            }
        }
    }
    
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        print("NotificationService: Received remote notification: \(userInfo)")
        
        // Extract notification data
        let title = userInfo["title"] as? String ?? "ZooBox Hero"
        let body = userInfo["body"] as? String ?? ""
        let sound = userInfo["sound"] as? String
        
        // Show notification if app is in foreground
        if UIApplication.shared.applicationState == .active {
            showLocalNotification(title: title, body: body, sound: sound)
        }
        
        // Handle specific notification types
        if let notificationType = userInfo["type"] as? String {
            handleNotificationType(notificationType, userInfo: userInfo)
        }
    }
    
    private func handleNotificationType(_ type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "new_order":
            handleNewOrderNotification(userInfo)
        case "delivery_update":
            handleDeliveryUpdateNotification(userInfo)
        case "location_request":
            handleLocationRequestNotification(userInfo)
        default:
            print("NotificationService: Unknown notification type: \(type)")
        }
    }
    
    private func handleNewOrderNotification(_ userInfo: [AnyHashable: Any]) {
        print("NotificationService: Handling new order notification")
        
        // Play custom sound
        playCustomSound("new_order_sound.caf")
        
        // You could also trigger specific actions here, like:
        // - Refresh the WebView
        // - Show specific UI
        // - Send location update
    }
    
    private func handleDeliveryUpdateNotification(_ userInfo: [AnyHashable: Any]) {
        print("NotificationService: Handling delivery update notification")
        
        // Play custom FCM sound
        playCustomSound("fcm_notification.caf")
    }
    
    private func handleLocationRequestNotification(_ userInfo: [AnyHashable: Any]) {
        print("NotificationService: Handling location request notification")
        
        // Force location update
        LocationService.shared.startLocationUpdates()
    }
    
    private func playCustomSound(_ soundFileName: String) {
        // Note: For iOS, custom sounds should be in the main bundle and in supported formats
        // The sound files should be converted to .caf format for iOS
        guard let soundURL = Bundle.main.url(forResource: soundFileName.replacingOccurrences(of: ".caf", with: ""), withExtension: "caf") else {
            print("NotificationService: Sound file not found: \(soundFileName)")
            return
        }
        
        // Play sound using AudioToolbox
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
        AudioServicesPlaySystemSound(soundID)
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func getBadgeCount() -> Int {
        return UIApplication.shared.applicationIconBadgeNumber
    }
    
    func setBadgeCount(_ count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("NotificationService: Will present notification: \(notification.request.content.title)")
        
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("NotificationService: User tapped notification: \(userInfo)")
        
        // Handle notification tap
        handleNotificationTap(userInfo)
        
        completionHandler()
    }
    
    private func handleNotificationTap(_ userInfo: [AnyHashable: Any]) {
        // Navigate to appropriate screen or perform action based on notification
        
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            // Open specific URL in the app's WebView
            NotificationCenter.default.post(name: .notificationTapped, object: url)
        } else {
            // Just open the app (default behavior)
            NotificationCenter.default.post(name: .notificationTapped, object: nil)
        }
    }
}

// MARK: - AudioToolbox Import
import AudioToolbox

// MARK: - Notification Names
extension Notification.Name {
    static let notificationTapped = Notification.Name("notificationTapped")
}