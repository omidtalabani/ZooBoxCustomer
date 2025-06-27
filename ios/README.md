# ZooBox Customer iOS App

This is the iOS version of the ZooBox Customer app, converted from the Android Kotlin version.

## Features

- **Splash Screen**: Video playback for 5 seconds
- **Connectivity Check**: Validates GPS and Internet connectivity
- **Permission Management**: Requests Location, Camera, and Notification permissions
- **WebView Integration**: Loads https://mikmik.site with cookie persistence
- **Background Location**: Tracks location every 15 seconds in background
- **Push Notifications**: FCM integration with custom sounds
- **Cookie Management**: Persistent session management

## App Flow

1. **SplashViewController**: Video splash screen (5 seconds)
2. **ConnectivityViewController**: GPS and Internet validation
3. **PermissionViewController**: Permission requests
4. **MainViewController**: WebView with location integration

## Technical Requirements

- iOS 14.0+
- Xcode 14.0+
- Swift 5.0+

## Key Components

### View Controllers
- `SplashViewController`: Handles video splash screen
- `ConnectivityViewController`: Checks GPS and Internet connectivity
- `PermissionViewController`: Manages permission requests
- `MainViewController`: WebView with cookie and location integration

### Services
- `LocationService`: Background location tracking and data sending
- `NotificationService`: FCM push notification handling
- `CookieManager`: Session and cookie persistence

### Permissions Required
- Location (When In Use)
- Location (Always) - for background tracking
- Camera - for delivery photos
- Push Notifications - for delivery updates

## Setup Instructions

1. Open `ZooBoxCustomer.xcodeproj` in Xcode
2. Replace `GoogleService-Info.plist` with your Firebase configuration
3. Update bundle identifier and signing certificates
4. Configure push notification certificates in Firebase
5. Build and run

## Firebase Configuration

Replace the placeholder `GoogleService-Info.plist` with your actual Firebase configuration file.

## Background Modes

The app is configured for:
- Location updates
- Background processing
- Remote notifications

## Sound Files

- `fcm_notification.caf`: FCM notification sound
- `new_order_sound.caf`: New order notification sound
- `splash.mp4`: Splash screen video

Note: Sound files should be converted to CAF format for optimal iOS compatibility.

## Deployment

1. Archive the project in Xcode
2. Upload to App Store Connect
3. Configure app metadata and screenshots
4. Submit for review

## License

This project maintains the same license as the original Android version.