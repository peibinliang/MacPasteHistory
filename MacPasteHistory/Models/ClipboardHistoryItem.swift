import Foundation

struct ClipboardHistoryItem: Identifiable, Equatable {
    let id: Int64
    let contentType: ClipboardContentType
    let textContent: String
    let filePath: String?
    let thumbnailPath: String?
    let sourceApp: String?
    let sourceBundleID: String?
    let contentHash: String
    let textLength: Int
    let fileSize: Int?
    let imageWidth: Int?
    let imageHeight: Int?
    let imageFormat: ClipboardImageFormat?
    let isFavorite: Bool
    let isSensitive: Bool
    let createdAt: Date
    let updatedAt: Date
    let searchableText: String?
    let detectedType: DetectedContentType?
    let userOverrideType: DetectedContentType?
    let detectionConfidence: Double?
    let detectionVersion: Int?
    let detectedAt: Date?
    let firstCapturedAt: Date?
    let lastCapturedAt: Date?
    let captureCount: Int
    let reuseCopyCount: Int
    let pasteCount: Int
    let lastReuseCopiedAt: Date?
    let lastPastedAt: Date?
    let ocrStatus: OCRStatus
    let ocrText: String?
    let ocrUpdatedAt: Date?
    let ocrErrorCode: String?
    let derivedFromHistoryID: Int64?
    let derivedActionID: String?
    let derivedActionSummary: String?
    let derivedAt: Date?
    let derivedSourcePreview: String?
    let derivedSourceHash: String?

    init(
        id: Int64,
        contentType: ClipboardContentType,
        textContent: String,
        filePath: String?,
        thumbnailPath: String?,
        sourceApp: String?,
        sourceBundleID: String?,
        contentHash: String,
        textLength: Int,
        fileSize: Int?,
        imageWidth: Int?,
        imageHeight: Int?,
        imageFormat: ClipboardImageFormat?,
        isFavorite: Bool,
        isSensitive: Bool,
        createdAt: Date,
        updatedAt: Date,
        searchableText: String? = nil,
        detectedType: DetectedContentType? = nil,
        userOverrideType: DetectedContentType? = nil,
        detectionConfidence: Double? = nil,
        detectionVersion: Int? = nil,
        detectedAt: Date? = nil,
        firstCapturedAt: Date? = nil,
        lastCapturedAt: Date? = nil,
        captureCount: Int = 1,
        reuseCopyCount: Int = 0,
        pasteCount: Int = 0,
        lastReuseCopiedAt: Date? = nil,
        lastPastedAt: Date? = nil,
        ocrStatus: OCRStatus = .notStarted,
        ocrText: String? = nil,
        ocrUpdatedAt: Date? = nil,
        ocrErrorCode: String? = nil,
        derivedFromHistoryID: Int64? = nil,
        derivedActionID: String? = nil,
        derivedActionSummary: String? = nil,
        derivedAt: Date? = nil,
        derivedSourcePreview: String? = nil,
        derivedSourceHash: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.sourceApp = sourceApp
        self.sourceBundleID = sourceBundleID
        self.contentHash = contentHash
        self.textLength = textLength
        self.fileSize = fileSize
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageFormat = imageFormat
        self.isFavorite = isFavorite
        self.isSensitive = isSensitive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.searchableText = searchableText
        self.detectedType = detectedType
        self.userOverrideType = userOverrideType
        self.detectionConfidence = detectionConfidence
        self.detectionVersion = detectionVersion
        self.detectedAt = detectedAt
        self.firstCapturedAt = firstCapturedAt
        self.lastCapturedAt = lastCapturedAt
        self.captureCount = captureCount
        self.reuseCopyCount = reuseCopyCount
        self.pasteCount = pasteCount
        self.lastReuseCopiedAt = lastReuseCopiedAt
        self.lastPastedAt = lastPastedAt
        self.ocrStatus = ocrStatus
        self.ocrText = ocrText
        self.ocrUpdatedAt = ocrUpdatedAt
        self.ocrErrorCode = ocrErrorCode
        self.derivedFromHistoryID = derivedFromHistoryID
        self.derivedActionID = derivedActionID
        self.derivedActionSummary = derivedActionSummary
        self.derivedAt = derivedAt
        self.derivedSourcePreview = derivedSourcePreview
        self.derivedSourceHash = derivedSourceHash
    }

    var effectiveDetectedType: DetectedContentType {
        userOverrideType ?? detectedType ?? (contentType == .image ? .image : .plainText)
    }

    var displayDate: Date {
        lastCapturedAt ?? createdAt
    }

    var isDerived: Bool {
        derivedActionID != nil
    }
}
