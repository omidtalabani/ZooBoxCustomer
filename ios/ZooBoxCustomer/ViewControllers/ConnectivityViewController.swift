import UIKit
import CoreLocation
import Network

class ConnectivityViewController: UIViewController {
    
    private let locationManager = CLLocationManager()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private var titleLabel: UILabel!
    private var activityIndicator: UIActivityIndicatorView!
    private var statusLabel: UILabel!
    
    private var gpsDialogShown = false
    private var internetDialogShown = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupLocationManager()
        setupNetworkMonitor()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkConnectivity()
    }
    
    private func setupUI() {
        // Set background color to match Android (#0077B6)
        view.backgroundColor = UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0)
        
        // Title label
        titleLabel = UILabel()
        titleLabel.text = "Checking Connectivity"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        // Activity indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        
        // Status label
        statusLabel = UILabel()
        statusLabel.text = "Please wait..."
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        
        // Setup constraints
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    private func setupNetworkMonitor() {
        monitor.start(queue: queue)
    }
    
    private func checkConnectivity() {
        // Reset dialog flags
        gpsDialogShown = false
        internetDialogShown = false
        
        // Check GPS
        let gpsEnabled = isGPSEnabled()
        
        // Check Internet
        let internetConnected = isInternetConnected()
        
        if !gpsEnabled {
            showEnableGPSDialog()
        } else if !internetConnected {
            showEnableInternetDialog()
        } else {
            // Both GPS and Internet are available
            proceedToPermissionsCheck()
        }
    }
    
    private func isGPSEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    private func isInternetConnected() -> Bool {
        let path = monitor.currentPath
        return path.status == .satisfied
    }
    
    private func showEnableGPSDialog() {
        guard !gpsDialogShown else { return }
        gpsDialogShown = true
        
        DispatchQueue.main.async {
            self.statusLabel.text = "GPS is required for location tracking"
            
            let alert = UIAlertController(
                title: "GPS Required",
                message: "Please enable GPS/Location Services to continue using the app. This is required for location tracking and delivery services.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            })
            
            self.present(alert, animated: true)
        }
    }
    
    private func showEnableInternetDialog() {
        guard !internetDialogShown else { return }
        internetDialogShown = true
        
        DispatchQueue.main.async {
            self.statusLabel.text = "Internet connection is required"
            
            let alert = UIAlertController(
                title: "Internet Required",
                message: "Please check your internet connection. WiFi or mobile data is required to use this app.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsUrl = URL(string: "App-Prefs:WIFI") {
                    UIApplication.shared.open(settingsUrl)
                } else if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            })
            
            self.present(alert, animated: true)
        }
    }
    
    private func proceedToPermissionsCheck() {
        DispatchQueue.main.async {
            self.statusLabel.text = "Connectivity verified!"
            
            // Wait a moment before proceeding
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let permissionVC = PermissionViewController()
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController = permissionVC
                    
                    // Add transition animation
                    let transition = CATransition()
                    transition.type = .fade
                    transition.duration = 0.3
                    window.layer.add(transition, forKey: kCATransition)
                }
            }
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - CLLocationManagerDelegate
extension ConnectivityViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Check connectivity again when location authorization changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkConnectivity()
        }
    }
}