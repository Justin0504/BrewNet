import Foundation
import UIKit
import UserNotifications

// MARK: - Push Manager(Stage 3,2026-08)
//
// 职责:请求通知权限 → 注册远程推送 → 把 device token 上报 device_tokens 表。
// 服务端由 apns-push edge function + cron 扫描(提案/成局/简报/Weekly)触发推送。

final class PushManager: NSObject {

    static let shared = PushManager()
    private override init() {}

    private let askedKey = "brew_push_permission_asked"

    /// 登录后调用(每次启动都可调,内部去重):已授权→直接注册;未问过→请求
    func requestIfAppropriate() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            case .notDetermined:
                guard !UserDefaults.standard.bool(forKey: self.askedKey) else { return }
                UserDefaults.standard.set(true, forKey: self.askedKey)
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    print("🔔 [Push] permission granted=\(granted)")
                    if granted {
                        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
                    }
                }
            default:
                break   // 用户明确拒绝过,不纠缠
            }
        }
    }

    /// AppDelegate 拿到 token 后调用:上报(按 token upsert)
    func uploadToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard let userId = storedCurrentUserId() else {
            print("🔔 [Push] no logged-in user, skip token upload")
            return
        }
        print("🔔 [Push] token=\(token.prefix(16))… uploading for user \(userId.prefix(8))")
        Task {
            struct TokenUpsert: Encodable {
                let user_id: String, token: String, platform: String, updated_at: String
            }
            do {
                _ = try await SupabaseConfig.shared.client
                    .from("device_tokens")
                    .upsert(TokenUpsert(user_id: userId.lowercased(), token: token,
                                        platform: "ios",
                                        updated_at: ISO8601DateFormatter().string(from: Date())),
                            onConflict: "token")
                    .execute()
                print("✅ [Push] token uploaded")
            } catch {
                print("⚠️ [Push] token upload failed: \(error.localizedDescription)")
            }
        }
    }

    private func storedCurrentUserId() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "current_user"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else { return nil }
        return id
    }
}

// MARK: - App Delegate(远程推送回调)

final class BrewAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.uploadToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ [Push] register failed: \(error.localizedDescription)")
    }

    // 前台也显示通知
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
