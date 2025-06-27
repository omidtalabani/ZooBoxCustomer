import UIKit
import AVFoundation

class SplashViewController: UIViewController {
    
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupVideoPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    private func setupVideoPlayer() {
        // Set background color to match Android (white)
        view.backgroundColor = UIColor.white
        
        guard let videoPath = Bundle.main.path(forResource: "splash", ofType: "mp4") else {
            print("Video file not found")
            // Fallback to timer-based splash
            showFallbackSplash()
            return
        }
        
        let videoURL = URL(fileURLWithPath: videoPath)
        player = AVPlayer(url: videoURL)
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspectFill
        
        if let playerLayer = playerLayer {
            view.layer.addSublayer(playerLayer)
        }
        
        // Add observer for when video ends
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        
        // Start playing video
        player?.play()
        
        // Fallback timer in case video doesn't load or play
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.navigateToNextScreen()
        }
    }
    
    private func showFallbackSplash() {
        // Create a simple splash screen with app logo/name
        let titleLabel = UILabel()
        titleLabel.text = "ZooBox Hero"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 32)
        titleLabel.textColor = UIColor(red: 0.0, green: 0.47, blue: 0.71, alpha: 1.0) // #0077B6
        titleLabel.textAlignment = .center
        
        view.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Timer for 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.navigateToNextScreen()
        }
    }
    
    @objc private func videoDidEnd() {
        navigateToNextScreen()
    }
    
    private func navigateToNextScreen() {
        DispatchQueue.main.async {
            // Navigate to ConnectivityViewController
            let connectivityVC = ConnectivityViewController()
            
            // Present modally or push depending on navigation setup
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = connectivityVC
                
                // Add transition animation
                let transition = CATransition()
                transition.type = .fade
                transition.duration = 0.3
                window.layer.add(transition, forKey: kCATransition)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
}