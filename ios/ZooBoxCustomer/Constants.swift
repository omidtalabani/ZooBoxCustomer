import Foundation

struct Constants {
    
    // MARK: - URLs
    struct URLs {
        static let baseURL = "https://mikmik.site"
        static let locationAPI = "\(baseURL)/api/location"
        static let fcmTokenAPI = "\(baseURL)/api/fcm-token"
    }
    
    // MARK: - Timing
    struct Timing {
        static let splashDuration: TimeInterval = 5.0
        static let locationUpdateInterval: TimeInterval = 15.0
        static let locationDistanceFilter: Double = 10.0
        static let connectivityCheckDelay: TimeInterval = 1.0
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let userId = "user_id"
        static let fcmToken = "fcm_token"
        static let apnsToken = "apns_token"
        static let cookies = "ZooBoxCustomerCookies"
        static let hasSeenPermissions = "has_seen_permissions"
        static let locationPermissionGranted = "location_permission_granted"
    }
    
    // MARK: - Notification Names
    struct NotificationNames {
        static let locationUpdated = "LocationUpdated"
        static let cookiesUpdated = "CookiesUpdated"
        static let permissionGranted = "PermissionGranted"
        static let networkStatusChanged = "NetworkStatusChanged"
    }
    
    // MARK: - Colors
    struct Colors {
        static let primaryBlue = "#0077B6"
        static let lightBlue = "#00B4D8"
        static let paleBlue = "#90E0EF"
        static let white = "#FFFFFF"
        static let black = "#000000"
        static let gray = "#888888"
        static let errorRed = "#FF6B6B"
        static let successGreen = "#51CF66"
    }
    
    // MARK: - Fonts
    struct Fonts {
        static let titleSize: CGFloat = 28
        static let headlineSize: CGFloat = 24
        static let bodySize: CGFloat = 16
        static let captionSize: CGFloat = 14
        static let smallSize: CGFloat = 12
        static let buttonSize: CGFloat = 16
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
        static let xxLarge: CGFloat = 48
    }
    
    // MARK: - Animation
    struct Animation {
        static let defaultDuration: TimeInterval = 0.3
        static let fastDuration: TimeInterval = 0.15
        static let slowDuration: TimeInterval = 0.5
        static let springDamping: CGFloat = 0.8
        static let springVelocity: CGFloat = 0.5
    }
    
    // MARK: - Location
    struct Location {
        static let desiredAccuracy = 10.0 // meters
        static let significantLocationChangeDistance = 500.0 // meters
        static let backgroundLocationTimeout: TimeInterval = 30.0 // seconds
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let noInternetConnection = "No internet connection. Please check your network and try again."
        static let locationPermissionDenied = "Location permission is required for this app to function properly."
        static let cameraPermissionDenied = "Camera permission is required to take delivery photos."
        static let notificationPermissionDenied = "Push notification permission is required to receive delivery updates."
        static let gpsDisabled = "GPS is disabled. Please enable location services in Settings."
        static let serverError = "Server error. Please try again later."
        static let unknownError = "An unknown error occurred. Please try again."
        static let webViewLoadError = "Failed to load the website. Please check your connection."
    }
    
    // MARK: - Success Messages
    struct SuccessMessages {
        static let locationPermissionGranted = "Location permission granted successfully."
        static let allPermissionsGranted = "All permissions granted. Welcome to ZooBox Hero!"
        static let connectivityVerified = "Connectivity verified successfully."
    }
    
    // MARK: - Button Titles
    struct ButtonTitles {
        static let continueTitle = "Continue"
        static let tryAgain = "Try Again"
        static let settings = "Settings"
        static let allowPermission = "Allow"
        static let skip = "Skip"
        static let done = "Done"
        static let cancel = "Cancel"
        static let ok = "OK"
        static let refresh = "Refresh"
        static let welcome = "Welcome to ZooBox Hero"
    }
    
    // MARK: - Permission Types
    enum PermissionType: String, CaseIterable {
        case location = "location"
        case backgroundLocation = "background_location"
        case notifications = "notifications"
        case camera = "camera"
        
        var title: String {
            switch self {
            case .location:
                return "Location Access"
            case .backgroundLocation:
                return "Background Location"
            case .notifications:
                return "Push Notifications"
            case .camera:
                return "Camera Access"
            }
        }
        
        var description: String {
            switch self {
            case .location:
                return "Required for tracking delivery progress"
            case .backgroundLocation:
                return "Allows location tracking when app is closed"
            case .notifications:
                return "Receive delivery updates and notifications"
            case .camera:
                return "Take photos for delivery confirmation"
            }
        }
        
        var isRequired: Bool {
            switch self {
            case .location, .backgroundLocation, .notifications:
                return true
            case .camera:
                return false
            }
        }
    }
    
    // MARK: - File Names
    struct FileNames {
        static let splashVideo = "splash.mp4"
        static let fcmNotificationSound = "fcm_notification.caf"
        static let newOrderSound = "new_order_sound.caf"
        static let googleServiceInfo = "GoogleService-Info.plist"
    }
}