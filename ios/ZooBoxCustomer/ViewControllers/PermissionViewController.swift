import UIKit
import CoreLocation
import UserNotifications
import AVFoundation

class PermissionViewController: UIViewController {
    
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var titleLabel: UILabel!
    private var descriptionLabel: UILabel!
    private var permissionStackView: UIStackView!
    private var proceedButton: UIButton!
    
    private let locationManager = CLLocationManager()
    
    // Permission tracking
    private var permissionSteps: [PermissionStep] = []
    private var currentStepIndex = 0
    private var isProcessingPermission = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPermissionSteps()
        setupUI()
        setupLocationManager()
        checkAllPermissions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-check permissions when returning from settings
        checkAllPermissions()
    }
    
    private func setupPermissionSteps() {
        permissionSteps = [
            PermissionStep(type: .location, title: "Location Access", description: "Required for tracking delivery progress", isGranted: false, isRequired: true),
            PermissionStep(type: .backgroundLocation, title: "Background Location", description: "Allows location tracking when app is closed", isGranted: false, isRequired: true),
            PermissionStep(type: .notifications, title: "Push Notifications", description: "Receive delivery updates and notifications", isGranted: false, isRequired: true),
            PermissionStep(type: .camera, title: "Camera Access", description: "Take photos for delivery confirmation", isGranted: false, isRequired: false)
        ]
    }
    
    private func setupUI() {
        // Set gradient background like Android
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0).cgColor,  // #0077B6
            UIColor(red: 0.0, green: 0.71, blue: 0.85, alpha: 1.0).cgColor,  // #00B4D8
            UIColor(red: 0.56, green: 0.88, blue: 0.94, alpha: 1.0).cgColor   // #90E0EF
        ]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Setup scroll view
        scrollView = UIScrollView()
        contentView = UIView()
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Title
        titleLabel = UILabel()
        titleLabel.text = "Permission Setup"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        // Description
        descriptionLabel = UILabel()
        descriptionLabel.text = "ZooBox Hero needs the following permissions to provide the best delivery experience. Please grant all required permissions to continue."
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.lineBreakMode = .byWordWrapping
        
        // Permission stack view
        permissionStackView = UIStackView()
        permissionStackView.axis = .vertical
        permissionStackView.spacing = 16
        permissionStackView.distribution = .fillEqually
        
        // Proceed button
        proceedButton = UIButton(type: .system)
        proceedButton.setTitle("Welcome to ZooBox Hero", for: .normal)
        proceedButton.setTitleColor(UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0), for: .normal)
        proceedButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        proceedButton.backgroundColor = .white
        proceedButton.layer.cornerRadius = 16
        proceedButton.layer.shadowColor = UIColor.black.cgColor
        proceedButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        proceedButton.layer.shadowOpacity = 0.1
        proceedButton.layer.shadowRadius = 8
        proceedButton.addTarget(self, action: #selector(proceedButtonTapped), for: .touchUpInside)
        
        // Add subviews
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(permissionStackView)
        contentView.addSubview(proceedButton)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionStackView.translatesAutoresizingMaskIntoConstraints = false
        proceedButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            permissionStackView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            permissionStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            permissionStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            
            proceedButton.topAnchor.constraint(greaterThanOrEqualTo: permissionStackView.bottomAnchor, constant: 32),
            proceedButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            proceedButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            proceedButton.heightAnchor.constraint(equalToConstant: 56),
            proceedButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        setupPermissionViews()
    }
    
    private func setupPermissionViews() {
        permissionStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, step) in permissionSteps.enumerated() {
            let permissionView = createPermissionView(for: step, at: index)
            permissionStackView.addArrangedSubview(permissionView)
        }
    }
    
    private func createPermissionView(for step: PermissionStep, at index: Int) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        let iconLabel = UILabel()
        iconLabel.text = step.type.icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        
        let titleLabel = UILabel()
        titleLabel.text = step.title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .white
        
        let descLabel = UILabel()
        descLabel.text = step.description
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        descLabel.numberOfLines = 0
        
        let statusIcon = UILabel()
        statusIcon.text = step.isGranted ? "✅" : (step.isRequired ? "⚠️" : "ℹ️")
        statusIcon.font = UIFont.systemFont(ofSize: 20)
        
        let requestButton = UIButton(type: .system)
        requestButton.setTitle(step.isGranted ? "Granted" : "Request", for: .normal)
        requestButton.setTitleColor(step.isGranted ? .systemGreen : .white, for: .normal)
        requestButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        requestButton.backgroundColor = step.isGranted ? UIColor.white.withAlphaComponent(0.2) : UIColor.white.withAlphaComponent(0.3)
        requestButton.layer.cornerRadius = 8
        requestButton.tag = index
        requestButton.addTarget(self, action: #selector(requestPermission(_:)), for: .touchUpInside)
        requestButton.isEnabled = !step.isGranted
        
        containerView.addSubview(iconLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descLabel)
        containerView.addSubview(statusIcon)
        containerView.addSubview(requestButton)
        
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        requestButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            iconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: statusIcon.leadingAnchor, constant: -8),
            
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            
            statusIcon.trailingAnchor.constraint(equalTo: requestButton.leadingAnchor, constant: -8),
            statusIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            requestButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            requestButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            requestButton.widthAnchor.constraint(equalToConstant: 80),
            requestButton.heightAnchor.constraint(equalToConstant: 32),
            
            descLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
        
        return containerView
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
    }
    
    @objc private func requestPermission(_ sender: UIButton) {
        guard !isProcessingPermission else { return }
        
        let stepIndex = sender.tag
        guard stepIndex < permissionSteps.count else { return }
        
        let step = permissionSteps[stepIndex]
        currentStepIndex = stepIndex
        isProcessingPermission = true
        
        switch step.type {
        case .location:
            requestLocationPermission()
        case .backgroundLocation:
            requestBackgroundLocationPermission()
        case .notifications:
            requestNotificationPermission()
        case .camera:
            requestCameraPermission()
        }
    }
    
    @objc private func proceedButtonTapped() {
        checkAllPermissions()
        
        // Check if all required permissions are granted
        let requiredPermissionsGranted = permissionSteps.filter { $0.isRequired }.allSatisfy { $0.isGranted }
        
        if requiredPermissionsGranted {
            proceedToMainApp()
        } else {
            showPermissionRequiredAlert()
        }
    }
    
    private func proceedToMainApp() {
        let mainVC = MainViewController()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = mainVC
            
            // Add transition animation
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.3
            window.layer.add(transition, forKey: kCATransition)
        }
    }
    
    private func showPermissionRequiredAlert() {
        let alert = UIAlertController(
            title: "Permissions Required",
            message: "Please grant all required permissions to use ZooBox Hero. You can update permissions in the Settings app.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}

// MARK: - Permission Requests
extension PermissionViewController {
    
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func requestBackgroundLocationPermission() {
        // First check if when-in-use permission is granted
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            showBackgroundLocationAlert()
            isProcessingPermission = false
            return
        }
        
        locationManager.requestAlwaysAuthorization()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.handleNotificationPermissionResult(granted: granted, error: error)
            }
        }
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.handleCameraPermissionResult(granted: granted)
            }
        }
    }
    
    private func showBackgroundLocationAlert() {
        let alert = UIAlertController(
            title: "Background Location Required",
            message: "Please first grant 'When In Use' location permission, then we can request background location access.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Permission Results
extension PermissionViewController {
    
    private func handleNotificationPermissionResult(granted: Bool, error: Error?) {
        isProcessingPermission = false
        
        if let index = permissionSteps.firstIndex(where: { $0.type == .notifications }) {
            permissionSteps[index].isGranted = granted
            updatePermissionView(at: index)
        }
        
        checkAllPermissions()
    }
    
    private func handleCameraPermissionResult(granted: Bool) {
        isProcessingPermission = false
        
        if let index = permissionSteps.firstIndex(where: { $0.type == .camera }) {
            permissionSteps[index].isGranted = granted
            updatePermissionView(at: index)
        }
        
        checkAllPermissions()
    }
    
    private func updatePermissionView(at index: Int) {
        guard index < permissionStackView.arrangedSubviews.count else { return }
        
        let permissionView = permissionStackView.arrangedSubviews[index]
        permissionStackView.removeArrangedSubview(permissionView)
        permissionView.removeFromSuperview()
        
        let newView = createPermissionView(for: permissionSteps[index], at: index)
        permissionStackView.insertArrangedSubview(newView, at: index)
    }
    
    private func checkAllPermissions() {
        // Check location permissions
        let locationStatus = locationManager.authorizationStatus
        if let index = permissionSteps.firstIndex(where: { $0.type == .location }) {
            permissionSteps[index].isGranted = (locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways)
            updatePermissionView(at: index)
        }
        
        if let index = permissionSteps.firstIndex(where: { $0.type == .backgroundLocation }) {
            permissionSteps[index].isGranted = (locationStatus == .authorizedAlways)
            updatePermissionView(at: index)
        }
        
        // Check notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if let index = self?.permissionSteps.firstIndex(where: { $0.type == .notifications }) {
                    self?.permissionSteps[index].isGranted = (settings.authorizationStatus == .authorized)
                    self?.updatePermissionView(at: index)
                }
            }
        }
        
        // Check camera permissions
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if let index = permissionSteps.firstIndex(where: { $0.type == .camera }) {
            permissionSteps[index].isGranted = (cameraStatus == .authorized)
            updatePermissionView(at: index)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        isProcessingPermission = false
        checkAllPermissions()
    }
}

// MARK: - Supporting Types
enum PermissionType {
    case location
    case backgroundLocation
    case notifications
    case camera
    
    var icon: String {
        switch self {
        case .location: return "📍"
        case .backgroundLocation: return "🗺️"
        case .notifications: return "🔔"
        case .camera: return "📷"
        }
    }
}

struct PermissionStep {
    let type: PermissionType
    let title: String
    let description: String
    var isGranted: Bool
    let isRequired: Bool
}