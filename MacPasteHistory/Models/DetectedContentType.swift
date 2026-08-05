import Foundation

enum DetectedContentType: String, CaseIterable, Codable {
    case plainText
    case image
    case json
    case url
    case base64
    case jwt
    case timestamp
    case sql
    case shell
}
