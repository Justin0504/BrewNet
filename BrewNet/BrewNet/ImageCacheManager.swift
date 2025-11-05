import Foundation
import SwiftUI
import UIKit
import CryptoKit

/// 图片缓存管理器 - 用于缓存头像图片，避免重复下载
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    // 内存缓存大小限制（50MB）
    private let maxMemoryCacheSize = 50 * 1024 * 1024
    
    private init() {
        // 设置内存缓存大小限制
        memoryCache.totalCostLimit = maxMemoryCacheSize
        
        // 创建缓存目录
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDir.appendingPathComponent("AvatarCache", isDirectory: true)
        
        // 确保缓存目录存在
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // print("📁 Avatar cache directory: \(cacheDirectory.path)")
    }
    
    /// 获取缓存文件的 URL
    private func cacheFileURL(for urlString: String) -> URL {
        // 使用 URL 的 MD5 哈希作为文件名（避免特殊字符问题）
        let fileName = urlString.md5
        return cacheDirectory.appendingPathComponent(fileName)
    }
    
    /// 从缓存加载图片
    func loadImage(from urlString: String) -> UIImage? {
        // 1. 先检查内存缓存
        if let cachedImage = memoryCache.object(forKey: urlString as NSString) {
            return cachedImage
        }
        
        // 2. 检查磁盘缓存
        let cacheFileURL = self.cacheFileURL(for: urlString)
        if fileManager.fileExists(atPath: cacheFileURL.path),
           let imageData = try? Data(contentsOf: cacheFileURL),
           let image = UIImage(data: imageData) {
            // 将图片加载到内存缓存
            memoryCache.setObject(image, forKey: urlString as NSString)
            return image
        }
        
        return nil
    }
    
    /// 保存图片到缓存
    func saveImage(_ image: UIImage, for urlString: String) {
        // 1. 保存到内存缓存
        memoryCache.setObject(image, forKey: urlString as NSString)
        
        // 2. 保存到磁盘缓存（异步，不阻塞主线程）
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                return
            }
            
            let cacheFileURL = self.cacheFileURL(for: urlString)
            try? imageData.write(to: cacheFileURL)
        }
    }
    
    /// 清除指定 URL 的缓存
    func removeImage(for urlString: String) {
        // 从内存缓存中移除
        memoryCache.removeObject(forKey: urlString as NSString)
        
        // 从磁盘缓存中移除
        let cacheFileURL = self.cacheFileURL(for: urlString)
        if fileManager.fileExists(atPath: cacheFileURL.path) {
            try? fileManager.removeItem(at: cacheFileURL)
            print("🗑️ [ImageCache] 已清除头像缓存: \(urlString)")
        }
    }
    
    /// 清除所有缓存
    func clearCache() {
        memoryCache.removeAllObjects()
        
        // 删除磁盘缓存目录
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        print("🗑️ Cleared all avatar cache")
    }
    
    /// 清除过期的缓存（可选：定期清理）
    func clearExpiredCache(maxAge: TimeInterval = 7 * 24 * 60 * 60) { // 默认7天
        let now = Date()
        
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               now.timeIntervalSince(creationDate) > maxAge {
                try? fileManager.removeItem(at: file)
                print("🗑️ Removed expired cache: \(file.lastPathComponent)")
            }
        }
    }
}

// MARK: - String MD5 Extension
extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

