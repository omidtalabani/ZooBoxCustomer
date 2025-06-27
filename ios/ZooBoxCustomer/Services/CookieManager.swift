import Foundation
import WebKit

class CookieManager {
    static let shared = CookieManager()
    
    private let cookieStore = WKWebsiteDataStore.default().httpCookieStore
    private let userDefaults = UserDefaults.standard
    private let cookieKey = "ZooBoxCustomerCookies"
    
    private init() {}
    
    // MARK: - Cookie Persistence
    
    func saveCookies(completion: (() -> Void)? = nil) {
        cookieStore.getAllCookies { [weak self] cookies in
            let cookieData = cookies.compactMap { cookie in
                return self?.cookieToDictionary(cookie)
            }
            
            self?.userDefaults.set(cookieData, forKey: self?.cookieKey ?? "")
            self?.userDefaults.synchronize()
            
            print("CookieManager: Saved \(cookies.count) cookies")
            
            DispatchQueue.main.async {
                completion?()
            }
        }
    }
    
    func loadCookies(completion: @escaping () -> Void) {
        guard let cookieDataArray = userDefaults.array(forKey: cookieKey) as? [[String: Any]] else {
            print("CookieManager: No cookies to load")
            completion()
            return
        }
        
        let cookies = cookieDataArray.compactMap { cookieDict in
            return cookieFromDictionary(cookieDict)
        }
        
        let group = DispatchGroup()
        
        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("CookieManager: Loaded \(cookies.count) cookies")
            completion()
        }
    }
    
    func clearCookies(completion: @escaping () -> Void) {
        cookieStore.getAllCookies { [weak self] cookies in
            let group = DispatchGroup()
            
            for cookie in cookies {
                group.enter()
                self?.cookieStore.delete(cookie) {
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self?.userDefaults.removeObject(forKey: self?.cookieKey ?? "")
                self?.userDefaults.synchronize()
                print("CookieManager: Cleared all cookies")
                completion()
            }
        }
    }
    
    // MARK: - Cookie Utilities
    
    func getUserIdFromCookies(completion: @escaping (String?) -> Void) {
        cookieStore.getAllCookies { cookies in
            // Look for common user ID cookie names
            let userIdCookieNames = ["user_id", "userId", "uid", "session_id", "sessionId"]
            
            for cookieName in userIdCookieNames {
                if let cookie = cookies.first(where: { $0.name == cookieName }) {
                    print("CookieManager: Found user ID in cookie '\(cookieName)': \(cookie.value)")
                    completion(cookie.value)
                    return
                }
            }
            
            // Also check for any cookie that might contain user information
            for cookie in cookies {
                if cookie.name.lowercased().contains("user") || 
                   cookie.name.lowercased().contains("id") {
                    print("CookieManager: Found potential user cookie '\(cookie.name)': \(cookie.value)")
                    completion(cookie.value)
                    return
                }
            }
            
            print("CookieManager: No user ID found in cookies")
            completion(nil)
        }
    }
    
    func setCookie(name: String, value: String, domain: String, path: String = "/", completion: @escaping () -> Void) {
        var cookieProperties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        
        if let cookie = HTTPCookie(properties: cookieProperties) {
            cookieStore.setCookie(cookie) {
                print("CookieManager: Set cookie '\(name)' = '\(value)'")
                completion()
            }
        } else {
            print("CookieManager: Failed to create cookie")
            completion()
        }
    }
    
    func getCookie(name: String, completion: @escaping (String?) -> Void) {
        cookieStore.getAllCookies { cookies in
            if let cookie = cookies.first(where: { $0.name == name }) {
                completion(cookie.value)
            } else {
                completion(nil)
            }
        }
    }
    
    func addCookiesToRequest(_ request: inout URLRequest, for url: URL) {
        // Get cookies for the specific URL
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
    }
    
    // MARK: - Cookie Serialization
    
    private func cookieToDictionary(_ cookie: HTTPCookie) -> [String: Any] {
        var dict: [String: Any] = [
            "name": cookie.name,
            "value": cookie.value,
            "domain": cookie.domain,
            "path": cookie.path
        ]
        
        if let expiresDate = cookie.expiresDate {
            dict["expires"] = expiresDate.timeIntervalSince1970
        }
        
        dict["secure"] = cookie.isSecure
        dict["httpOnly"] = cookie.isHTTPOnly
        
        if let sameSite = cookie.sameSitePolicy {
            switch sameSite {
            case .lax:
                dict["sameSite"] = "Lax"
            case .strict:
                dict["sameSite"] = "Strict"
            case .none:
                dict["sameSite"] = "None"
            @unknown default:
                dict["sameSite"] = "Lax"
            }
        }
        
        return dict
    }
    
    private func cookieFromDictionary(_ dict: [String: Any]) -> HTTPCookie? {
        guard let name = dict["name"] as? String,
              let value = dict["value"] as? String,
              let domain = dict["domain"] as? String,
              let path = dict["path"] as? String else {
            return nil
        }
        
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        
        if let expiresTimestamp = dict["expires"] as? TimeInterval {
            properties[.expires] = Date(timeIntervalSince1970: expiresTimestamp)
        }
        
        if let secure = dict["secure"] as? Bool, secure {
            properties[.secure] = "TRUE"
        }
        
        if let httpOnly = dict["httpOnly"] as? Bool, httpOnly {
            properties[.init(rawValue: "HttpOnly")] = "TRUE"
        }
        
        if let sameSite = dict["sameSite"] as? String {
            properties[.sameSitePolicy] = sameSite
        }
        
        return HTTPCookie(properties: properties)
    }
    
    // MARK: - Debug Methods
    
    func printAllCookies() {
        cookieStore.getAllCookies { cookies in
            print("CookieManager: Current cookies (\(cookies.count)):")
            for cookie in cookies {
                print("  - \(cookie.name) = \(cookie.value) (domain: \(cookie.domain), path: \(cookie.path))")
            }
        }
    }
    
    func getCookieCount(completion: @escaping (Int) -> Void) {
        cookieStore.getAllCookies { cookies in
            completion(cookies.count)
        }
    }
    
    // MARK: - Migration from older storage
    
    func migrateLegacyCookies() {
        // If you're migrating from an older version that stored cookies differently,
        // you can implement migration logic here
        
        // For example, migrating from UserDefaults to WKHTTPCookieStore
        if let legacyCookieData = userDefaults.data(forKey: "legacy_cookies") {
            // Migrate legacy cookies
            print("CookieManager: Migrating legacy cookies...")
            userDefaults.removeObject(forKey: "legacy_cookies")
        }
    }
}

// MARK: - Cookie Sync with HTTPCookieStorage
extension CookieManager {
    
    func syncWithHTTPCookieStorage() {
        // Sync WKWebView cookies with HTTPCookieStorage for URLSession requests
        cookieStore.getAllCookies { cookies in
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
            print("CookieManager: Synced \(cookies.count) cookies with HTTPCookieStorage")
        }
    }
    
    func syncFromHTTPCookieStorage() {
        // Sync HTTPCookieStorage cookies to WKWebView
        guard let cookies = HTTPCookieStorage.shared.cookies else { return }
        
        let group = DispatchGroup()
        
        for cookie in cookies {
            group.enter()
            cookieStore.setCookie(cookie) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("CookieManager: Synced \(cookies.count) cookies from HTTPCookieStorage")
        }
    }
}