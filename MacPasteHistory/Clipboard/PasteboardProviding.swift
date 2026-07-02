import AppKit
import Foundation

protocol PasteboardProviding: AnyObject {
    var changeCount: Int { get }
    func data(forType dataType: NSPasteboard.PasteboardType) -> Data?
    func fileURLs() -> [URL]
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func image() -> NSImage?
    func clearContents() -> Int
    func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardProviding {
    func fileURLs() -> [URL] {
        let objects = readObjects(forClasses: [NSURL.self], options: nil) ?? []
        return objects.compactMap { object in
            guard let url = object as? URL, url.isFileURL else {
                return nil
            }
            return url
        }
    }

    func image() -> NSImage? {
        return NSImage(pasteboard: self)
    }
}
