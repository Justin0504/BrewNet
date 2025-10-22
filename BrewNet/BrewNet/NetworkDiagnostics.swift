import Foundation
import Network

// MARK: - Network Diagnostics
class NetworkDiagnostics: ObservableObject {
    static let shared = NetworkDiagnostics()
    
    @Published var isConnected = false
    @Published var connectionType: String = "未知"
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = "WiFi"
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = "蜂窝网络"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = "有线网络"
                } else {
                    self?.connectionType = "其他"
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func testSupabaseConnectivity() async -> (success: Bool, details: String) {
        guard let url = URL(string: "https://jcxvdolcdifdghaibspy.supabase.co") else {
            return (false, "无效的 URL")
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                let success = statusCode >= 200 && statusCode < 300
                
                return (success, "HTTP \(statusCode)")
            }
            
            return (false, "无效的响应")
            
        } catch {
            return (false, error.localizedDescription)
        }
    }
    
    deinit {
        monitor.cancel()
    }
}
