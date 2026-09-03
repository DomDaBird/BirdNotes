import Foundation

public enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case notebook
    case infiniteCanvas
    case pdf
}

public enum LibraryItemKind: String, Codable, Sendable {
    case folder
    case notebook
    case infiniteCanvas
    case technicalDiagram
    case pdf
}

public struct LibraryItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: LibraryItemKind
    public let relativePath: String
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        id: String,
        name: String,
        kind: LibraryItemKind,
        relativePath: String,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.relativePath = relativePath
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct DeletedLibraryItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let kind: LibraryItemKind?
    public let originalRelativePath: String
    public let deletedAt: Date

    public init(
        id: String,
        name: String,
        kind: LibraryItemKind?,
        originalRelativePath: String,
        deletedAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.originalRelativePath = originalRelativePath
        self.deletedAt = deletedAt
    }
}

public struct LibraryBackupManifest: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let createdAt: Date
    public let itemCount: Int
    public let includesTrash: Bool

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        createdAt: Date,
        itemCount: Int,
        includesTrash: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.itemCount = itemCount
        self.includesTrash = includesTrash
    }
}

public enum BackupConflictPolicy: String, Codable, CaseIterable, Sendable {
    case keepBoth
    case skip
    case replace
}

public struct LibraryBackupPreview: Equatable, Sendable {
    public let createdAt: Date
    public let itemCount: Int
    public let itemNames: [String]
    public let conflictingItemNames: [String]

    public init(
        createdAt: Date,
        itemCount: Int,
        itemNames: [String],
        conflictingItemNames: [String]
    ) {
        self.createdAt = createdAt
        self.itemCount = itemCount
        self.itemNames = itemNames
        self.conflictingItemNames = conflictingItemNames
    }
}

public struct LibraryBackupRestoreResult: Equatable, Sendable {
    public let restoredPaths: [String]
    public let skippedItemNames: [String]

    public init(restoredPaths: [String], skippedItemNames: [String]) {
        self.restoredPaths = restoredPaths
        self.skippedItemNames = skippedItemNames
    }
}

public struct LibraryTextSearchHit: Identifiable, Hashable, Sendable {
    public let documentPath: String
    public let pageID: UUID
    public let pageNumber: Int
    public let excerpt: String

    public var id: String { "\(documentPath)#\(pageID.uuidString)" }

    public init(documentPath: String, pageID: UUID, pageNumber: Int, excerpt: String) {
        self.documentPath = documentPath
        self.pageID = pageID
        self.pageNumber = pageNumber
        self.excerpt = excerpt
    }
}

public struct ExternalConflictVersion: Identifiable, Hashable, Sendable {
    public let id: String
    public let modifiedAt: Date?
    public let deviceName: String?
    public let localizedName: String?

    public init(id: String, modifiedAt: Date?, deviceName: String?, localizedName: String?) {
        self.id = id
        self.modifiedAt = modifiedAt
        self.deviceName = deviceName
        self.localizedName = localizedName
    }
}

public struct ExternalDocumentConflict: Identifiable, Hashable, Sendable {
    public let documentPath: String
    public let documentName: String
    public let currentModifiedAt: Date
    public let versions: [ExternalConflictVersion]

    public var id: String { documentPath }

    public init(
        documentPath: String,
        documentName: String,
        currentModifiedAt: Date,
        versions: [ExternalConflictVersion]
    ) {
        self.documentPath = documentPath
        self.documentName = documentName
        self.currentModifiedAt = currentModifiedAt
        self.versions = versions
    }
}

public enum ExternalConflictResolution: Equatable, Sendable {
    case keepCurrent
    case useSelected
    case keepBoth
}

public enum LibrarySort: String, CaseIterable, Identifiable, Sendable {
    case name
    case createdAt
    case modifiedAt

    public var id: Self { self }

    public func sort(_ items: [LibraryItem]) -> [LibraryItem] {
        items.sorted { lhs, rhs in
            if lhs.kind == .folder, rhs.kind != .folder { return true }
            if lhs.kind != .folder, rhs.kind == .folder { return false }

            switch self {
            case .name:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .createdAt:
                return lhs.createdAt > rhs.createdAt
            case .modifiedAt:
                return lhs.modifiedAt > rhs.modifiedAt
            }
        }
    }
}

public struct LibraryState: Codable, Equatable, Sendable {
    public static let maximumRecentItems = 20
    public static let maximumFavoriteItems = 10_000
    public static let maximumTagsPerItem = 12
    public static let maximumTagLength = 40

    public var favoritePaths: [String]
    public var recentPaths: [String]
    public var tagsByPath: [String: [String]]

    public init(
        favoritePaths: [String] = [],
        recentPaths: [String] = [],
        tagsByPath: [String: [String]] = [:]
    ) {
        self.favoritePaths = Array(favoritePaths.prefix(Self.maximumFavoriteItems))
        self.recentPaths = Array(recentPaths.prefix(Self.maximumRecentItems))
        self.tagsByPath = tagsByPath
    }

    private enum CodingKeys: String, CodingKey {
        case favoritePaths
        case recentPaths
        case tagsByPath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            favoritePaths: try container.decodeIfPresent([String].self, forKey: .favoritePaths) ?? [],
            recentPaths: try container.decodeIfPresent([String].self, forKey: .recentPaths) ?? [],
            tagsByPath: try container.decodeIfPresent([String: [String]].self, forKey: .tagsByPath) ?? [:]
        )
    }
}
