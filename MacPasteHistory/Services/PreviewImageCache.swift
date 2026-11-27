import AppKit
import Foundation
import ImageIO

final class PreviewImageCache: @unchecked Sendable {
    static let shared = PreviewImageCache()

    private let imageCache = NSCache<NSString, NSImage>()
    private let appIconCache = NSCache<NSString, NSImage>()

    init(
        maxImageCount: Int = DefaultSettings.previewImageCacheCountLimit,
        maxImageBytes: Int = DefaultSettings.previewImageCacheByteLimit,
        maxAppIconCount: Int = DefaultSettings.appIconCacheCountLimit
    ) {
        imageCache.countLimit = maxImageCount
        imageCache.totalCostLimit = maxImageBytes
        appIconCache.countLimit = maxAppIconCount
    }

    func image(atPath path: String?, fitting size: NSSize) -> NSImage? {
        guard let path, path.isEmpty == false else {
            return nil
        }
        let maxPixelDimension = max(64, Int(ceil(max(size.width, size.height) * 2)))
        let cacheKey = "\(path)#\(maxPixelDimension)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        let fileURL = URL(fileURLWithPath: path)
        guard let decoded = Self.downsampleImage(at: fileURL, maxPixelDimension: maxPixelDimension)
                ?? NSImage(contentsOfFile: path) else {
            return nil
        }

        let estimatedCost = max(1, maxPixelDimension * maxPixelDimension * 4)
        imageCache.setObject(decoded, forKey: cacheKey, cost: estimatedCost)
        return decoded
    }

    func applicationIcon(forBundleIdentifier bundleID: String) -> NSImage? {
        let key = bundleID as NSString
        if let cached = appIconCache.object(forKey: key) {
            return cached
        }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        appIconCache.setObject(icon, forKey: key)
        return icon
    }

    func removeImages(forPath path: String?) {
        guard let path, path.isEmpty == false else {
            return
        }
        // Evict common display buckets (row thumbnail 108px and detail preview 1080px).
        for bucket in [108, 160, 320, 1_080] {
            imageCache.removeObject(forKey: "\(path)#\(bucket)" as NSString)
        }
    }

    func removeAll() {
        imageCache.removeAllObjects()
    }

    private static func downsampleImage(at url: URL, maxPixelDimension: Int) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
