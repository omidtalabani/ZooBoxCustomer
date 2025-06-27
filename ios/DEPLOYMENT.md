# ZooBox Customer iOS - Deployment Guide

## Prerequisites

1. **Xcode 14.0+** installed on macOS
2. **Apple Developer Account** (for App Store deployment)
3. **Firebase Project** set up for iOS
4. **Push Notification Certificates** configured in Firebase

## Setup Steps

### 1. Firebase Configuration

1. Create a new iOS app in your Firebase console
2. Download the `GoogleService-Info.plist` file
3. Replace the placeholder file in the iOS project
4. Configure Firebase Cloud Messaging for push notifications

### 2. Xcode Project Configuration

1. Open `ZooBoxCustomer.xcodeproj` in Xcode
2. Update the following settings:
   - **Bundle Identifier**: Change to your unique identifier (e.g., `com.yourcompany.zooboxcustomer`)
   - **Team**: Select your Apple Developer Team
   - **Deployment Target**: iOS 14.0 or later

### 3. Signing & Capabilities

Configure the following capabilities in Xcode:

1. **Background Modes**:
   - Location updates
   - Background processing
   - Remote notifications

2. **Push Notifications**: Enable push notifications capability

3. **App Transport Security**: Already configured to allow arbitrary loads

### 4. Location Services

The app requires the following location permissions:
- **When In Use**: For basic location functionality
- **Always**: For background location tracking

### 5. Firebase Integration

If you want to add Firebase SDK (recommended):

1. Add Firebase to your Xcode project using Swift Package Manager:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```

2. Add the following frameworks:
   - FirebaseCore
   - FirebaseMessaging
   - FirebaseAnalytics (optional)

3. Update `AppDelegate.swift` to initialize Firebase:
   ```swift
   import FirebaseCore
   
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
       FirebaseApp.configure()
       return true
   }
   ```

### 6. Testing

#### Local Testing
1. Build and run on simulator for basic functionality
2. Test on physical device for location and push notifications

#### TestFlight Distribution
1. Archive the project in Xcode
2. Upload to App Store Connect
3. Add internal/external testers
4. Test all functionality including background location

### 7. App Store Submission

#### Prepare App Store Metadata
1. App name: "ZooBox Hero"
2. Keywords: delivery, tracking, food delivery, location
3. Description: (Copy from Android app store listing)
4. Screenshots: Take screenshots from iPhone and iPad
5. Privacy Policy URL: Required for location and camera permissions

#### Required Information
- **Location Usage**: Explain why the app needs location access
- **Camera Usage**: Explain camera is for delivery photos
- **Background Usage**: Explain background location for delivery tracking

### 8. Production Configuration

#### Before release:
1. Update `GoogleService-Info.plist` with production Firebase config
2. Ensure all API endpoints point to production servers
3. Test with production Firebase project
4. Verify push notifications work with production certificates

#### Security Checklist:
- [ ] No hardcoded API keys in source code
- [ ] Firebase security rules configured
- [ ] SSL certificate pinning (if required)
- [ ] Obfuscation of sensitive data

### 9. Post-Release

#### Monitoring:
1. Set up Firebase Crashlytics for crash reporting
2. Monitor Firebase Analytics for user behavior
3. Track location service performance
4. Monitor push notification delivery rates

#### Updates:
1. Use TestFlight for beta testing
2. Submit updates through App Store Connect
3. Maintain compatibility with older iOS versions

## Common Issues

### Location Permission Issues
- Make sure location usage descriptions are clear and specific
- Test on physical device (simulator has limitations)
- Check that background location is properly configured

### Push Notification Issues
- Verify APNs certificates in Firebase
- Test with production certificates before release
- Check that device tokens are being sent to server

### WebView Issues
- Test with various network conditions
- Verify cookie persistence works correctly
- Check JavaScript injection functionality

### Background Mode Issues
- Test background location with real-world scenarios
- Verify app doesn't drain battery excessively
- Check that location data is sent correctly

## Support

For technical issues with the iOS implementation:
1. Check Xcode console for error messages
2. Verify Firebase configuration
3. Test network connectivity
4. Review Apple Developer documentation for latest requirements

## App Store Review Guidelines

Ensure compliance with:
- Location Services Guidelines
- Push Notification Guidelines
- Background App Refresh Guidelines
- Data Collection and Storage Guidelines