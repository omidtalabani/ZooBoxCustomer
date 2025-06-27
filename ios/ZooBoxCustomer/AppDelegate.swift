import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure Firebase if available
        // FirebaseApp.configure()
        
        // Request notification permissions
        NotificationService.shared.requestPermission()
        
        // Configure notification categories
        NotificationService.shared.configureNotificationCategories()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    // MARK: - Push Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.setAPNSToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    // Handle background app refresh
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Start background location updates if permission granted
        LocationService.shared.startBackgroundLocationUpdates()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Resume normal location updates
        LocationService.shared.startLocationUpdates()
    }
}