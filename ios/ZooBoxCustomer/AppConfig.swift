import Foundation

/// Configuration manager for ZooBox Customer app
class AppConfig {
    static let shared = AppConfig()
    
    private init() {}
    
    // MARK: - App Information
    var appName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "ZooBox Hero"
    }
    
    var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.zoobox.customer"
    }
    
    // MARK: - Environment Configuration
    var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    var baseURL: String {
        return isDebugMode ? "https://mikmik.site" : "https://mikmik.site"
    }
    
    var locationAPIEndpoint: String {
        return "\(baseURL)/api/location"
    }
    
    var fcmTokenAPIEndpoint: String {
        return "\(baseURL)/api/fcm-token"
    }
    
    // MARK: - Feature Flags
    var isLocationTrackingEnabled: Bool {
        return UserDefaults.standard.object(forKey: "location_tracking_enabled") as? Bool ?? true
    }
    
    var isPushNotificationsEnabled: Bool {
        return UserDefaults.standard.object(forKey: "push_notifications_enabled") as? Bool ?? true
    }
    
    var isAnalyticsEnabled: Bool {
        return UserDefaults.standard.object(forKey: "analytics_enabled") as? Bool ?? true
    }
    
    var isCrashReportingEnabled: Bool {
        return UserDefaults.standard.object(forKey: "crash_reporting_enabled") as? Bool ?? true
    }
    
    // MARK: - Location Configuration
    var locationUpdateInterval: TimeInterval {
        return UserDefaults.standard.object(forKey: "location_update_interval") as? TimeInterval ?? 15.0
    }
    
    var locationAccuracyThreshold: Double {
        return UserDefaults.standard.object(forKey: "location_accuracy_threshold") as? Double ?? 10.0
    }
    
    var backgroundLocationEnabled: Bool {
        return UserDefaults.standard.object(forKey: "background_location_enabled") as? Bool ?? true
    }
    
    // MARK: - Network Configuration
    var requestTimeoutInterval: TimeInterval {
        return 30.0
    }
    
    var maxRetryAttempts: Int {
        return 3
    }
    
    var retryDelay: TimeInterval {
        return 2.0
    }
    
    // MARK: - UI Configuration
    var splashScreenDuration: TimeInterval {
        return 5.0
    }
    
    var animationDuration: TimeInterval {
        return 0.3
    }
    
    var showDebugInfo: Bool {
        return isDebugMode
    }
    
    // MARK: - Logging Configuration
    var loggingEnabled: Bool {
        return isDebugMode
    }
    
    var logLevel: LogLevel {
        return isDebugMode ? .debug : .error
    }
    
    // MARK: - Methods
    func updateLocationTrackingEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "location_tracking_enabled")
    }
    
    func updatePushNotificationsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "push_notifications_enabled")
    }
    
    func updateAnalyticsEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "analytics_enabled")
    }
    
    func updateLocationUpdateInterval(_ interval: TimeInterval) {
        UserDefaults.standard.set(interval, forKey: "location_update_interval")
    }
    
    func resetToDefaults() {
        let keys = [
            "location_tracking_enabled",
            "push_notifications_enabled",
            "analytics_enabled",
            "crash_reporting_enabled",
            "location_update_interval",
            "location_accuracy_threshold",
            "background_location_enabled"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // MARK: - Debug Methods
    func printConfiguration() {
        guard isDebugMode else { return }
        
        print("=== ZooBox Customer Configuration ===")
        print("App Name: \(appName)")
        print("Version: \(appVersion) (\(buildNumber))")
        print("Bundle ID: \(bundleIdentifier)")
        print("Base URL: \(baseURL)")
        print("Location Tracking: \(isLocationTrackingEnabled)")
        print("Push Notifications: \(isPushNotificationsEnabled)")
        print("Analytics: \(isAnalyticsEnabled)")
        print("Location Update Interval: \(locationUpdateInterval)s")
        print("====================================")
    }
}

enum LogLevel: Int {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}