import Foundation
import CoreLocation
import SwiftUI

// MARK: - Location Service
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()
    
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String?
    @Published var isLocating = false
    @Published var locationError: String?
    
    private var geocoder = CLGeocoder()
    
    // 缓存地理编码结果，避免重复编码相同地址
    private var geocodeCache: [String: CLLocation] = [:]
    private let cacheQueue = DispatchQueue(label: "com.brewnet.geocodeCache")
    
    // ⭐ 新增：缓存距离计算结果，避免重复计算相同地址对的距离
    private var distanceCache: [String: Double] = [:]
    
    // ⭐ 新增：跟踪正在进行的地理编码请求，避免重复请求
    private var pendingRequests: [String: [(CLLocation?) -> Void]] = [:]
    private let requestsQueue = DispatchQueue(label: "com.brewnet.pendingRequests")
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Request Permission
    func requestLocationPermission() {
        guard authorizationStatus == .notDetermined else {
            print("ℹ️ Location permission already requested: \(authorizationStatus.rawValue)")
            return
        }
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Get Current Location
    func getCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            locationError = "Location permission not granted"
            if authorizationStatus == .notDetermined {
                // 如果权限未确定，先请求权限，设置 isLocating 标志
                isLocating = true
                requestLocationPermission()
            }
            return
        }
        
        isLocating = true
        locationError = nil
        locationManager.requestLocation()
    }
    
    // MARK: - Reverse Geocode (Convert coordinates to address)
    private func reverseGeocode(location: CLLocation) {
        // 记录坐标信息用于调试
        print("📍 Getting address for coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLocating = false
                
                if let error = error {
                    self?.locationError = "Failed to get address: \(error.localizedDescription)"
                    print("⚠️ Reverse geocoding error: \(error.localizedDescription)")
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self?.locationError = "No address found"
                    print("⚠️ No placemark found")
                    return
                }
                
                // 打印详细地址信息用于调试
                print("🔍 Placemark details:")
                print("   - Locality (城市): \(placemark.locality ?? "nil")")
                print("   - SubLocality (子区域): \(placemark.subLocality ?? "nil")")
                print("   - AdministrativeArea (州/省): \(placemark.administrativeArea ?? "nil")")
                print("   - SubAdministrativeArea (子行政区): \(placemark.subAdministrativeArea ?? "nil")")
                print("   - Country (国家): \(placemark.country ?? "nil")")
                print("   - PostalCode (邮编): \(placemark.postalCode ?? "nil")")
                
                // 构建地址字符串（优先使用更详细的信息）
                var addressComponents: [String] = []
                
                // 优先使用 subLocality（如 "Downtown", "Mission District"），如果没有则使用 locality（城市）
                if let subLocality = placemark.subLocality, !subLocality.isEmpty {
                    // 如果 subLocality 和 locality 相同，只保留一个
                    if subLocality != placemark.locality {
                        addressComponents.append(subLocality)
                    }
                }
                
                if let city = placemark.locality {
                    addressComponents.append(city)
                }
                
                if let state = placemark.administrativeArea {
                    addressComponents.append(state)
                }
                
                if let country = placemark.country {
                    // 如果是美国，使用州名；其他国家使用国家名
                    if country == "United States" {
                        // 已经添加了州名，跳过国家
                    } else {
                        addressComponents.append(country)
                    }
                }
                
                let address = addressComponents.joined(separator: ", ")
                self?.currentAddress = address.isEmpty ? nil : address
                
                if let address = self?.currentAddress {
                    print("✅ Current location: \(address)")
                    print("   📌 Accuracy: ±\(location.horizontalAccuracy)m")
                } else {
                    print("⚠️ Address is empty after processing")
                }
            }
        }
    }
    
    // MARK: - Calculate Distance
    func calculateDistance(from location1: CLLocation, to location2: CLLocation) -> Double {
        return location1.distance(from: location2) / 1000.0 // 返回公里
    }
    
    // MARK: - Calculate Distance in Meters
    func calculateDistanceInMeters(from location1: CLLocation, to location2: CLLocation) -> Double {
        return location1.distance(from: location2) // 返回米
    }
    
    // MARK: - Calculate Distance Between Two GPS Coordinates
    func calculateDistanceBetweenCoordinates(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double,
        completion: @escaping (Double?) -> Void
    ) {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        let distance = calculateDistanceInMeters(from: location1, to: location2)
        print("📏 [实时距离] 计算距离: (\(lat1), \(lon1)) 到 (\(lat2), \(lon2)) = \(formatDistance(distance / 1000.0))")
        completion(distance)
    }
    
    // MARK: - Format Distance
    func formatDistance(_ kilometers: Double) -> String {
        if kilometers < 1 {
            return String(format: "%.0f m", kilometers * 1000)
        } else if kilometers < 10 {
            return String(format: "%.1f km", kilometers)
        } else {
            return String(format: "%.0f km", kilometers)
        }
    }
    
    // MARK: - Geocode Address (Convert address string to coordinates)
    func geocodeAddress(_ address: String, completion: @escaping (CLLocation?) -> Void) {
        guard !address.isEmpty else {
            completion(nil)
            return
        }
        
        // 1. 检查缓存
        var cachedLocation: CLLocation?
        cacheQueue.sync {
            cachedLocation = geocodeCache[address]
        }
        
        if let cached = cachedLocation {
            print("✅ [缓存] 使用缓存的坐标: \(address)")
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }
        
        // 2. ⭐ 检查是否已有相同地址的请求正在进行
        var shouldStartNewRequest = false
        requestsQueue.sync {
            if var callbacks = pendingRequests[address] {
                // 已有请求在进行，添加到回调列表
                callbacks.append(completion)
                pendingRequests[address] = callbacks
                print("⏳ [请求去重] 地址 '\(address)' 已有请求在进行，加入等待队列")
            } else {
                // 没有进行中的请求，创建新请求
                pendingRequests[address] = [completion]
                shouldStartNewRequest = true
                print("🌍 [地理编码] 开始新请求: '\(address)'")
            }
        }
        
        // 如果不需要发起新请求（已有请求在进行），直接返回
        guard shouldStartNewRequest else { return }
        
        // 3. 进行地理编码
        geocoder.geocodeAddressString(address) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            // 获取所有等待这个地址结果的回调
            var callbacks: [(CLLocation?) -> Void] = []
            self.requestsQueue.sync {
                callbacks = self.pendingRequests[address] ?? []
                self.pendingRequests.removeValue(forKey: address)
            }
            
            DispatchQueue.main.async {
                let location: CLLocation?
                
                if let error = error {
                    print("⚠️ [地理编码] 编码失败: \(error.localizedDescription)")
                    location = nil
                } else if let placemark = placemarks?.first, let placeLocation = placemark.location {
                    location = placeLocation
                    
                    // 存入缓存
                    self.cacheQueue.async {
                        self.geocodeCache[address] = placeLocation
                        print("💾 [缓存] 已缓存地址: \(address)")
                    }
                    
                    print("✅ [地理编码] 编码成功: \(address) -> (\(placeLocation.coordinate.latitude), \(placeLocation.coordinate.longitude))")
                } else {
                    print("⚠️ [地理编码] 无位置结果: \(address)")
                    location = nil
                }
                
                // ⭐ 通知所有等待的回调
                print("📢 [请求去重] 通知 \(callbacks.count) 个等待的回调")
                for callback in callbacks {
                    callback(location)
                }
            }
        }
    }
    
    // MARK: - Clear Geocode Cache
    func clearGeocodeCache() {
        cacheQueue.async {
            self.geocodeCache.removeAll()
            print("🗑️ [缓存] 已清空地理编码缓存")
        }
    }
    
    // MARK: - Clear Distance Cache
    func clearDistanceCache() {
        distanceCache.removeAll()
        print("🗑️ [缓存] 已清空距离缓存")
    }
    
    // MARK: - Clear All Caches
    func clearAllCaches() {
        clearGeocodeCache()
        clearDistanceCache()
        print("🗑️ [缓存] 已清空所有缓存")
    }
    
    // MARK: - Calculate Distance Between Two Addresses
    func calculateDistanceBetweenAddresses(
        address1: String?,
        address2: String?,
        completion: @escaping (Double?) -> Void
    ) {
        guard let address1 = address1, !address1.isEmpty,
              let address2 = address2, !address2.isEmpty else {
            completion(nil)
            return
        }
        
        // 如果两个地址相同，距离为0
        if address1 == address2 {
            completion(0.0)
            return
        }
        
        // ⭐ 检查距离缓存（双向检查：A->B 和 B->A）
        let cacheKey1 = "\(address1)||\(address2)"
        let cacheKey2 = "\(address2)||\(address1)"
        
        if let cachedDistance = distanceCache[cacheKey1] ?? distanceCache[cacheKey2] {
            print("⚡️ [距离缓存] 命中缓存: \(address1) <-> \(address2) = \(formatDistance(cachedDistance))")
            completion(cachedDistance)
            return
        }
        
        // 并行获取两个地址的坐标
        var location1: CLLocation?
        var location2: CLLocation?
        var completed = 0
        
        let group = DispatchGroup()
        
        group.enter()
        geocodeAddress(address1) { location in
            location1 = location
            completed += 1
            group.leave()
        }
        
        group.enter()
        geocodeAddress(address2) { location in
            location2 = location
            completed += 1
            group.leave()
        }
        
        group.notify(queue: .main) {
            print("🔍 [LocationService] 地理编码完成:")
            print("   - address1 '\(address1)' -> location1: \(location1 != nil ? "✅" : "❌ nil")")
            print("   - address2 '\(address2)' -> location2: \(location2 != nil ? "✅" : "❌ nil")")
            
            guard let loc1 = location1, let loc2 = location2 else {
                if location1 == nil {
                    print("❌ [LocationService] 地址1地理编码失败: '\(address1)'")
                }
                if location2 == nil {
                    print("❌ [LocationService] 地址2地理编码失败: '\(address2)'")
                }
                print("⚠️ [LocationService] 无法计算距离：地理编码失败")
                completion(nil)
                return
            }
            
            print("✅ [LocationService] 两个地址都成功编码:")
            print("   - \(address1): (\(loc1.coordinate.latitude), \(loc1.coordinate.longitude))")
            print("   - \(address2): (\(loc2.coordinate.latitude), \(loc2.coordinate.longitude))")
            
            let distance = self.calculateDistance(from: loc1, to: loc2)
            print("📏 [LocationService] 计算距离: '\(address1)' 到 '\(address2)' = \(self.formatDistance(distance))")
            
            // ⭐ 存入距离缓存
            self.distanceCache[cacheKey1] = distance
            print("💾 [距离缓存] 已缓存: \(address1) <-> \(address2) = \(self.formatDistance(distance))")
            
            completion(distance)
        }
    }
    
    // MARK: - Calculate Distance Between Current Location and Address
    func calculateDistanceFromCurrentLocation(
        to address: String?,
        completion: @escaping (Double?) -> Void
    ) {
        guard let address = address, !address.isEmpty else {
            completion(nil)
            return
        }
        
        // 如果当前已有位置，直接使用
        if let currentLocation = currentLocation {
            geocodeAddress(address) { location in
                guard let location = location else {
                    completion(nil)
                    return
                }
                let distance = self.calculateDistance(from: currentLocation, to: location)
                completion(distance)
            }
        } else {
            // 如果没有当前位置，先获取当前位置
            getCurrentLocation()
            
            // 等待位置更新（最多等待5秒）
            Task {
                for _ in 0..<50 {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
                    if let currentLocation = self.currentLocation {
                        self.geocodeAddress(address) { location in
                            guard let location = location else {
                                completion(nil)
                                return
                            }
                            let distance = self.calculateDistance(from: currentLocation, to: location)
                            completion(distance)
                        }
                        return
                    }
                }
                completion(nil)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLocating = false
            self.locationError = "Failed to get location: \(error.localizedDescription)"
            print("⚠️ Location error: \(error.localizedDescription)")
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        let oldStatus = authorizationStatus
        authorizationStatus = newStatus
        
        switch newStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted")
            // 如果权限从 notDetermined 变为 authorized，且之前请求过定位，自动获取
            if oldStatus == .notDetermined && isLocating {
                locationManager.requestLocation()
            }
        case .denied, .restricted:
            print("⚠️ Location permission denied")
            isLocating = false
            locationError = "Location permission denied. Please enable it in Settings."
        case .notDetermined:
            print("ℹ️ Location permission not determined")
        @unknown default:
            break
        }
    }
}

