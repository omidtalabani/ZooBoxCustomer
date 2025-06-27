import UIKit
import WebKit
import CoreLocation

class MainViewController: UIViewController {
    
    private var webView: WKWebView!
    private var refreshControl: UIRefreshControl!
    private var isLoading = false
    
    // Error state
    private var errorView: UIView?
    private var showErrorScreen = false
    private var errorType = "no_internet"
    private var errorMessage: String?
    
    // Location tracking
    private var lastKnownLocation: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupRefreshControl()
        setupLocationTracking()
        loadWebsite()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Start location service
        LocationService.shared.startLocationUpdates()
        LocationService.shared.delegate = self
        
        // Start cookie persistence service
        LocationService.shared.startCookieSending()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Save cookies when leaving
        CookieManager.shared.saveCookies()
    }
    
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        
        // Configure preferences
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Configure data store for cookie persistence
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Create web view
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.bounces = true
        webView.allowsBackForwardNavigationGestures = true
        
        // Enable geolocation
        webView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0)
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        
        webView.scrollView.addSubview(refreshControl)
        webView.scrollView.refreshControl = refreshControl
    }
    
    private func setupLocationTracking() {
        // Location service is already set up, just register for updates
        LocationService.shared.delegate = self
    }
    
    private func loadWebsite() {
        guard let url = URL(string: "https://mikmik.site") else {
            showError(type: "invalid_url", message: "Invalid website URL")
            return
        }
        
        // Load cookies before making request
        CookieManager.shared.loadCookies { [weak self] in
            DispatchQueue.main.async {
                let request = URLRequest(url: url)
                self?.webView.load(request)
            }
        }
    }
    
    @objc private func refreshWebView() {
        if let url = webView.url {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            loadWebsite()
        }
    }
    
    private func showError(type: String, message: String?) {
        hideErrorScreen()
        
        errorType = type
        errorMessage = message
        showErrorScreen = true
        
        let errorContainer = UIView()
        errorContainer.backgroundColor = UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0)
        
        let titleLabel = UILabel()
        titleLabel.text = getErrorTitle(for: type)
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        let messageLabel = UILabel()
        messageLabel.text = message ?? getErrorMessage(for: type)
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Try Again", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        retryButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        retryButton.layer.cornerRadius = 8
        retryButton.layer.borderWidth = 1
        retryButton.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        retryButton.addTarget(self, action: #selector(retryConnection), for: .touchUpInside)
        
        errorContainer.addSubview(titleLabel)
        errorContainer.addSubview(messageLabel)
        errorContainer.addSubview(retryButton)
        
        view.addSubview(errorContainer)
        errorView = errorContainer
        
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            errorContainer.topAnchor.constraint(equalTo: view.topAnchor),
            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: errorContainer.centerYAnchor, constant: -40),
            titleLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -32),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor, constant: -32),
            
            retryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            retryButton.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            retryButton.widthAnchor.constraint(equalToConstant: 120),
            retryButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func hideErrorScreen() {
        showErrorScreen = false
        errorView?.removeFromSuperview()
        errorView = nil
    }
    
    private func getErrorTitle(for type: String) -> String {
        switch type {
        case "no_internet":
            return "No Internet Connection"
        case "no_gps":
            return "GPS Required"
        case "server_error":
            return "Server Error"
        default:
            return "Connection Error"
        }
    }
    
    private func getErrorMessage(for type: String) -> String {
        switch type {
        case "no_internet":
            return "Please check your internet connection and try again."
        case "no_gps":
            return "Please enable GPS/Location Services to continue."
        case "server_error":
            return "The server is currently unavailable. Please try again later."
        default:
            return "Something went wrong. Please try again."
        }
    }
    
    @objc private func retryConnection() {
        hideErrorScreen()
        loadWebsite()
    }
    
    private func sendLocationToWebView(location: CLLocation) {
        let javascript = """
            (function() {
                if (window.setLocation && typeof window.setLocation === 'function') {
                    window.setLocation(\(location.coordinate.latitude), \(location.coordinate.longitude));
                }
                
                // Also update any location display elements
                var locationElements = document.querySelectorAll('[data-location]');
                locationElements.forEach(function(element) {
                    element.textContent = 'Lat: \(String(format: "%.6f", location.coordinate.latitude)), Lng: \(String(format: "%.6f", location.coordinate.longitude))';
                });
                
                // Trigger location update event
                var event = new CustomEvent('locationUpdate', {
                    detail: {
                        latitude: \(location.coordinate.latitude),
                        longitude: \(location.coordinate.longitude),
                        accuracy: \(location.horizontalAccuracy),
                        timestamp: \(Int(location.timestamp.timeIntervalSince1970 * 1000))
                    }
                });
                window.dispatchEvent(event);
            })();
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                print("Error sending location to WebView: \(error)")
            } else {
                print("Location sent to WebView successfully")
            }
        }
    }
    
    private func injectLocationScript() {
        let javascript = """
            (function() {
                // Helper function to check if element is clickable
                function isClickable(element) {
                    if (!element) return false;
                    
                    var style = window.getComputedStyle(element);
                    if (style.pointerEvents === 'none' || style.visibility === 'hidden' || style.display === 'none') {
                        return false;
                    }
                    
                    var tagName = element.tagName.toLowerCase();
                    var clickableTags = ['a', 'button', 'input', 'select', 'textarea', 'label'];
                    
                    if (clickableTags.includes(tagName)) return true;
                    if (element.onclick || element.getAttribute('onclick')) return true;
                    if (element.classList.contains('clickable') || element.classList.contains('btn')) return true;
                    if (element.hasAttribute('data-click') || element.hasAttribute('data-action')) return true;
                    
                    return false;
                }
                
                // Add click handlers for better interaction detection
                document.addEventListener('click', function(event) {
                    var element = event.target;
                    console.log('Clicked element:', element.tagName, element.className, element.id);
                });
                
                // Location update function that web content can call
                window.requestLocation = function() {
                    // This will be handled by the native app
                    console.log('Location requested by web content');
                };
                
                console.log('ZooBox location script injected successfully');
            })();
        """
        
        webView.evaluateJavaScript(javascript) { result, error in
            if let error = error {
                print("Error injecting location script: \(error)")
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension MainViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        refreshControl.beginRefreshing()
        hideErrorScreen()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        refreshControl.endRefreshing()
        
        // Save cookies after page loads
        CookieManager.shared.saveCookies()
        
        // Send last known location to WebView if available
        if let location = lastKnownLocation {
            sendLocationToWebView(location: location)
        }
        
        // Inject JavaScript for enhanced functionality
        injectLocationScript()
        
        print("WebView finished loading: \(webView.url?.absoluteString ?? "unknown")")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        refreshControl.endRefreshing()
        
        print("WebView failed to load: \(error.localizedDescription)")
        showError(type: "server_error", message: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        refreshControl.endRefreshing()
        
        print("WebView failed provisional navigation: \(error.localizedDescription)")
        
        if (error as NSError).code == NSURLErrorNotConnectedToInternet {
            showError(type: "no_internet", message: nil)
        } else {
            showError(type: "server_error", message: error.localizedDescription)
        }
    }
}

// MARK: - WKUIDelegate
extension MainViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })
        present(alert, animated: true)
    }
}

// MARK: - LocationServiceDelegate
extension MainViewController: LocationServiceDelegate {
    func locationService(_ service: LocationService, didUpdateLocation location: CLLocation) {
        lastKnownLocation = location
        sendLocationToWebView(location: location)
        
        print("Location updated in MainViewController: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationService(_ service: LocationService, didFailWithError error: Error) {
        print("Location service failed: \(error.localizedDescription)")
        // Optionally show GPS error
        // showError(type: "no_gps", message: error.localizedDescription)
    }
}