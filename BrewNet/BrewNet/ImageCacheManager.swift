import Foundation
import SwiftUI
import UIKit
import ImageIO

// MARK: - 图片缓存管理器
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let urlSession: URLSession
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    private let tasksLock = NSLock()  // 保护 loadingTasks 的线程安全
    
    private init() {
        // 配置缓存
        cache.countLimit = 100  // 最多缓存100张图片
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB 内存限制
        
        // 配置 URLSession 使用磁盘缓存
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20MB 内存缓存
            diskCapacity: 512 * 1024 * 1024,   // 512MB 磁盘缓存(原图多 MB,100MB 存不了几张)
            diskPath: "ImageCache"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - 同步检查缓存（仅检查内存缓存，不触发网络加载）
    func getCachedImage(from urlString: String) -> UIImage? {
        let cacheKey = urlString as NSString
        return cache.object(forKey: cacheKey)
    }
    
    // MARK: - 保存图片到缓存
    func saveImage(_ image: UIImage, for urlString: String) {
        let cacheKey = urlString as NSString
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: cacheKey, cost: cost)
    }
    
    // MARK: - 加载图片（带缓存）
    func loadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        
        let cacheKey = urlString as NSString
        
        // 1. 先检查内存缓存
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        // 2. 检查是否有正在加载的任务（线程安全）
        var existingTask: Task<Void, Never>?
        tasksLock.lock()
        existingTask = loadingTasks[urlString]
        tasksLock.unlock()
        
        if let existingTask = existingTask {
            await existingTask.value
            return cache.object(forKey: cacheKey)
        }
        
        // 3. 创建新的加载任务
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let (data, _) = try await self.urlSession.data(from: url)
                // 降采样解码:原图(4000px 级)解码后 ~48MB,一张就挤爆 50MB 缓存导致
                // 缓存永远 miss + 反复慢解码;限制长边 1200px 后单张 ≤5.5MB
                if let image = Self.downsampled(data: data, maxPixel: 1200) {
                    let cost = Int(image.size.width * image.size.height * 4)
                    self.cache.setObject(image, forKey: cacheKey, cost: cost)
                }
            } catch {
                print("⚠️ [ImageCache] 加载图片失败: \(urlString), 错误: \(error.localizedDescription)")
            }
            
            // 移除任务（线程安全）
            self.tasksLock.lock()
            self.loadingTasks.removeValue(forKey: urlString)
            self.tasksLock.unlock()
        }
        
        // 保存任务（线程安全）
        tasksLock.lock()
        loadingTasks[urlString] = task
        tasksLock.unlock()
        
        await task.value
        
        return cache.object(forKey: cacheKey)
    }
    
    // MARK: - 降采样解码(ImageIO,不把原图整张解进内存)
    static func downsampled(data: Data, maxPixel: CGFloat) -> UIImage? {
        let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else {
            return UIImage(data: data)
        }
        let thumbOpts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }

    // MARK: - 预加载图片
    func preloadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let cacheKey = urlString as NSString
        
        // 检查是否已缓存
        if cache.object(forKey: cacheKey) != nil {
            return
        }
        
        // 检查是否正在加载（线程安全）
        tasksLock.lock()
        let isLoading = loadingTasks[urlString] != nil
        tasksLock.unlock()
        
        if isLoading {
            return
        }
        
        Task {
            _ = await loadImage(from: urlString)
        }
    }
    
    // MARK: - 批量预加载
    func preloadImages(from urlStrings: [String]) {
        for urlString in urlStrings {
            preloadImage(from: urlString)
        }
    }
    
    // MARK: - 移除指定图片的缓存
    func removeImage(for urlString: String) {
        let cacheKey = urlString as NSString
        
        // 1. 从内存缓存中移除
        cache.removeObject(forKey: cacheKey)
        
        // 2. 从磁盘缓存中移除
        if let url = URL(string: urlString) {
            urlSession.configuration.urlCache?.removeCachedResponse(for: URLRequest(url: url))
        }
        
        // 3. 取消正在加载的任务（如果有，线程安全）
        tasksLock.lock()
        let task = loadingTasks[urlString]
        loadingTasks.removeValue(forKey: urlString)
        tasksLock.unlock()
        
        task?.cancel()
    }
    
    // MARK: - 清除所有缓存
    func clearCache() {
        cache.removeAllObjects()
        urlSession.configuration.urlCache?.removeAllCachedResponses()
        
        // 取消所有正在加载的任务（线程安全）
        tasksLock.lock()
        let tasks = Array(loadingTasks.values)
        loadingTasks.removeAll()
        tasksLock.unlock()
        
        for task in tasks {
            task.cancel()
        }
    }
}

// MARK: - AsyncImage(phase 版)的缓存替身
// 与 AsyncImage { phase in } 同签名,裸 AsyncImage 可原地改名接入共享缓存
struct CachedAsyncImagePhase<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
        if let url, let cached = ImageCacheManager.shared.getCachedImage(from: url.absoluteString) {
            _phase = State(initialValue: .success(Image(uiImage: cached)))
        } else {
            _phase = State(initialValue: .empty)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else { return }
                if case .success = phase { return }
                if let img = await ImageCacheManager.shared.loadImage(from: url.absoluteString) {
                    phase = .success(Image(uiImage: img))
                } else {
                    phase = .failure(URLError(.cannotLoadFromNetwork))
                }
            }
    }
}

// MARK: - 优化的 AsyncImage 视图
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        
        // 立即检查缓存，避免闪烁
        if let url = url {
            let urlString = url.absoluteString
            if let cachedImage = ImageCacheManager.shared.getCachedImage(from: urlString) {
                _loadedImage = State(initialValue: cachedImage)
                _isLoading = State(initialValue: false)
            }
        }
    }
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                content(Image(uiImage: loadedImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()  // 加载失败也显示占位符
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        let urlString = url.absoluteString
        
        // 如果已经有缓存图片，不再加载
        if loadedImage != nil {
            return
        }
        
        if let cachedImage = await ImageCacheManager.shared.loadImage(from: urlString) {
            await MainActor.run {
                // 检查 URL 是否仍然匹配（防止视图已销毁或 URL 已变化）
                if self.url?.absoluteString == urlString {
                    self.loadedImage = cachedImage
                    self.isLoading = false
                }
            }
        } else {
            await MainActor.run {
                // 检查 URL 是否仍然匹配
                if self.url?.absoluteString == urlString {
                    self.isLoading = false
                }
            }
        }
    }
}
