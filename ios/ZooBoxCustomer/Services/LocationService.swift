import CoreLocation
import UIKit

protocol LocationServiceDelegate: AnyObject {
    func locationService(_ service: LocationService, didUpdateLocation location: CLLocation)
    func locationService(_ service: LocationService, didFailWithError error: Error)
}

class LocationService: NSObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var sendTimer: Timer?
    
    weak var delegate: LocationServiceDelegate?
    
    // Location tracking
    private var lastKnownLocation: CLLocation?
    private var userId: String?
    
    // Constants
    private let sendInterval: TimeInterval = AppConfig.shared.locationUpdateInterval
    private let baseURL = AppConfig.shared.baseURL
    
    override init() {
        super.init()
        setupLocationManager()
        loadUserId()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = false // Will be enabled when permission granted
        
        // Request permission if not already determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    private func loadUserId() {
        // Try to load user ID from UserDefaults (equivalent to SharedPreferences)
        userId = UserDefaults.standard.string(forKey: "user_id")
        
        // Also try to get from cookies
        if userId == nil {
            CookieManager.shared.getUserIdFromCookies { [weak self] cookieUserId in
                if let cookieUserId = cookieUserId, !cookieUserId.isEmpty {
                    self?.userId = cookieUserId
                    UserDefaults.standard.set(cookieUserId, forKey: "user_id")
                    print("LocationService: Loaded user ID from cookies: \(cookieUserId)")
                }
            }
        }
    }
    
    func startLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            print("LocationService: Location permission not granted")
            return
        }
        
        print("LocationService: Starting location updates")
        locationManager.startUpdatingLocation()
        
        // Also start significant location changes for better battery efficiency
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    func startBackgroundLocationUpdates() {
        guard locationManager.authorizationStatus == .authorizedAlways else {
            print("LocationService: Background location permission not granted")
            return
        }
        
        print("LocationService: Starting background location updates")
        
        // Enable background location updates
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        startCookieSending()
    }
    
    func stopLocationUpdates() {
        print("LocationService: Stopping location updates")
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.allowsBackgroundLocationUpdates = false
        
        stopCookieSending()
    }
    
    func startCookieSending() {
        stopCookieSending() // Stop any existing timer
        
        print("LocationService: Starting cookie sending service")
        
        // Start periodic sending
        sendTimer = Timer.scheduledTimer(withTimeInterval: sendInterval, repeats: true) { [weak self] _ in
            self?.sendLocationData()
        }
        
        // Send immediately
        sendLocationData()
    }
    
    func stopCookieSending() {
        sendTimer?.invalidate()
        sendTimer = nil
        print("LocationService: Stopped cookie sending service")
    }
    
    private func sendLocationData() {
        guard let location = lastKnownLocation else {
            print("LocationService: No location available to send")
            return
        }
        
        // Load current user ID in case it was updated
        loadUserId()
        
        guard let userId = userId, !userId.isEmpty else {
            print("LocationService: No user ID available")
            return
        }
        
        let locationData: [String: Any] = [
            "user_id": userId,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "timestamp": Int(location.timestamp.timeIntervalSince1970 * 1000), // Milliseconds
            "speed": location.speed,
            "bearing": location.course,
            "altitude": location.altitude
        ]
        
        sendDataToServer(data: locationData)
    }
    
    private func sendDataToServer(data: [String: Any]) {
        guard let url = URL(string: "\(baseURL)/api/location") else {
            print("LocationService: Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add cookies to request
        CookieManager.shared.addCookiesToRequest(&request, for: url)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            print("LocationService: Error serializing location data: \(error)")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("LocationService: Error sending location data: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("LocationService: Location data sent successfully, status: \(httpResponse.statusCode)")
                
                // Save any new cookies from the response
                if let headerFields = httpResponse.allHeaderFields as? [String: String] {
                    let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                    for cookie in cookies {
                        HTTPCookieStorage.shared.setCookie(cookie)
                    }
                    
                    // Save cookies to persistent storage
                    DispatchQueue.main.async {
                        CookieManager.shared.saveCookies()
                    }
                }
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("LocationService: Response: \(responseString)")
            }
        }
        
        task.resume()
    }
    
    private func startBackgroundTask() {
        endBackgroundTask()
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "LocationUpdate") {
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        lastKnownLocation = location
        delegate?.locationService(self, didUpdateLocation: location)
        
        print("LocationService: Location updated - Lat: \(location.coordinate.latitude), Lng: \(location.coordinate.longitude), Accuracy: \(location.horizontalAccuracy)m")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationService: Location manager failed with error: \(error.localizedDescription)")
        delegate?.locationService(self, didFailWithError: error)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("LocationService: Authorization changed to: \(manager.authorizationStatus.rawValue)")
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            startLocationUpdates()
        case .authorizedAlways:
            startBackgroundLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("LocationService: Entered region: \(region.identifier)")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("LocationService: Exited region: \(region.identifier)")
    }
}