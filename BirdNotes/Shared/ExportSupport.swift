import Compression
import PDFKit
import PencilKit
import SwiftUI
import UIKit
import BirdNotesCore

struct PreparedBackupImport: Sendable {
    let packageURL: URL
    let cleanupURL: URL?
}

enum BackupImportSupport {
    private static let maximumArchiveBytes: Int64 = 4 * 1_024 * 1_024 * 1_024
    private static let maximumExpandedBytes: UInt64 = 20 * 1_024 * 1_024 * 1_024
    private static let maximumEntries = 100_000
    private static let maximumCompressionRatio: UInt64 = 500

    static func prepare(_ sourceURL: URL) throws -> PreparedBackupImport {
        if sourceURL.pathExtension.lowercased() == DocumentStore.backupExtension {
            return PreparedBackupImport(packageURL: sourceURL, cleanupURL: nil)
        }
        guard sourceURL.pathExtension.lowercased() == "zip" else {
            throw DocumentStoreError.unsupportedFileType(sourceURL.pathExtension)
        }

        let size = try sourceURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard size.isRegularFile == true, size.isSymbolicLink != true else {
            throw DocumentStoreError.damagedDocument("Das Backup-Archiv ist keine reguläre Datei.")
        }
        guard Int64(size.fileSize ?? 0) <= maximumArchiveBytes else {
            throw DocumentStoreError.resourceLimitExceeded("Backup-Archive dürfen höchstens 4 GB groß sein.")
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotes-Import-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            let entries = try parseArchive(at: sourceURL)
            try checkAvailableCapacity(for: entries, at: destination)
            for entry in entries {
                try extract(entry, from: sourceURL, to: destination)
            }
            let topLevel = try FileManager.default.contentsOfDirectory(
                at: destination,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            guard topLevel.count == 1,
                  topLevel[0].pathExtension.lowercased() == DocumentStore.backupExtension,
                  try topLevel[0].resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
                  try topLevel[0].resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
                throw DocumentStoreError.damagedDocument(
                    "Das ZIP enthält nicht genau ein BirdNotes-Backup-Paket."
                )
            }
            return PreparedBackupImport(packageURL: topLevel[0], cleanupURL: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private struct ZIPEntry {
        let path: String
        let compressionMethod: UInt16
        let checksum: UInt32
        let compressedSize: UInt64
        let uncompressedSize: UInt64
        let localHeaderOffset: UInt64

        var isDirectory: Bool { path.hasSuffix("/") }
    }

    private static func parseArchive(at url: URL) throws -> [ZIPEntry] {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard let endOffset = endOfCentralDirectoryOffset(in: data) else {
            throw DocumentStoreError.damagedDocument("Das ZIP-Endverzeichnis fehlt.")
        }
        let disk = try data.uint16LE(at: endOffset + 4)
        let centralDisk = try data.uint16LE(at: endOffset + 6)
        let entriesOnDisk = try data.uint16LE(at: endOffset + 8)
        let entryCount = try data.uint16LE(at: endOffset + 10)
        let centralSize = try data.uint32LE(at: endOffset + 12)
        let centralOffset = try data.uint32LE(at: endOffset + 16)
        guard disk == 0,
              centralDisk == 0,
              entriesOnDisk == entryCount,
              entryCount != UInt16.max,
              centralSize != UInt32.max,
              centralOffset != UInt32.max,
              Int(entryCount) <= maximumEntries,
              UInt64(centralOffset) + UInt64(centralSize) <= UInt64(data.count) else {
            throw DocumentStoreError.damagedDocument("Mehrteilige oder ZIP64-Archive werden nicht importiert.")
        }

        var offset = Int(centralOffset)
        var entries: [ZIPEntry] = []
        var expandedBytes: UInt64 = 0
        var pathKeys = Set<String>()
        for _ in 0..<Int(entryCount) {
            guard try data.uint32LE(at: offset) == 0x0201_4B50 else {
                throw DocumentStoreError.damagedDocument("Das ZIP-Dateiverzeichnis ist beschädigt.")
            }
            let flags = try data.uint16LE(at: offset + 8)
            let method = try data.uint16LE(at: offset + 10)
            let checksum = try data.uint32LE(at: offset + 16)
            let compressedSize = UInt64(try data.uint32LE(at: offset + 20))
            let uncompressedSize = UInt64(try data.uint32LE(at: offset + 24))
            let nameLength = Int(try data.uint16LE(at: offset + 28))
            let extraLength = Int(try data.uint16LE(at: offset + 30))
            let commentLength = Int(try data.uint16LE(at: offset + 32))
            let externalAttributes = try data.uint32LE(at: offset + 38)
            let localOffset = UInt64(try data.uint32LE(at: offset + 42))
            let end = offset + 46 + nameLength + extraLength + commentLength
            guard end <= data.count,
                  flags & 0x0001 == 0,
                  method == 0 || method == 8 else {
                throw DocumentStoreError.damagedDocument(
                    "Das ZIP ist verschlüsselt, beschädigt oder verwendet eine unbekannte Kompression."
                )
            }
            let unixType = (externalAttributes >> 16) & 0xF000
            guard unixType != 0xA000 else {
                throw DocumentStoreError.damagedDocument("Symbolische Links sind in Backups nicht erlaubt.")
            }
            let nameData = data.subdata(in: (offset + 46)..<(offset + 46 + nameLength))
            guard var path = String(data: nameData, encoding: .utf8) else {
                throw DocumentStoreError.damagedDocument("Ein ZIP-Pfad ist nicht UTF-8-kodiert.")
            }
            path = path.precomposedStringWithCanonicalMapping
            try validateArchivePath(path)
            let pathKey = path.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            guard pathKeys.insert(pathKey).inserted else {
                throw DocumentStoreError.damagedDocument("Das ZIP enthält mehrdeutige Dateipfade.")
            }

            expandedBytes += uncompressedSize
            guard expandedBytes <= maximumExpandedBytes,
                  uncompressedSize == 0
                    || compressedSize > 0
                    || method == 0,
                  compressedSize == 0
                    || uncompressedSize / max(1, compressedSize) <= maximumCompressionRatio else {
                throw DocumentStoreError.resourceLimitExceeded(
                    "Das ZIP ist zu groß oder weist ein verdächtiges Kompressionsverhältnis auf."
                )
            }
            entries.append(ZIPEntry(
                path: path,
                compressionMethod: method,
                checksum: checksum,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                localHeaderOffset: localOffset
            ))
            offset = end
        }
        guard offset <= Int(centralOffset + centralSize) else {
            throw DocumentStoreError.damagedDocument("Das ZIP-Dateiverzeichnis ist inkonsistent.")
        }
        return entries
    }

    private static func endOfCentralDirectoryOffset(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        let lowerBound = max(0, data.count - 65_557)
        var offset = data.count - 22
        while offset >= lowerBound {
            if (try? data.uint32LE(at: offset)) == 0x0605_4B50,
               let commentLength = try? data.uint16LE(at: offset + 20),
               offset + 22 + Int(commentLength) == data.count {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func validateArchivePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        let meaningful = path.hasSuffix("/") ? components.dropLast() : components[...]
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("\\"),
              !path.contains("\\"),
              !path.contains("\0"),
              meaningful.count <= DocumentStoreLimits.maximumBackupDepth,
              !meaningful.contains("."),
              !meaningful.contains(".."),
              !meaningful.contains(""),
              meaningful.allSatisfy({ $0.utf8.count <= 255 }) else {
            throw DocumentStoreError.damagedDocument("Das ZIP enthält einen unsicheren Pfad.")
        }
    }

    private static func checkAvailableCapacity(for entries: [ZIPEntry], at url: URL) throws {
        let required = Int64(entries.reduce(UInt64(0)) { $0 + $1.uncompressedSize })
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values.volumeAvailableCapacityForImportantUsage,
           available < required + 256 * 1_024 * 1_024 {
            throw DocumentStoreError.resourceLimitExceeded(
                "Für die sichere Wiederherstellung ist nicht genügend freier Speicher vorhanden."
            )
        }
    }

    private static func extract(_ entry: ZIPEntry, from archiveURL: URL, to destination: URL) throws {
        let outputURL = destination.appendingPathComponent(entry.path).standardizedFileURL
        guard outputURL.path.hasPrefix(destination.path + "/") else {
            throw DocumentStoreError.damagedDocument("Ein ZIP-Pfad verlässt das Importverzeichnis.")
        }
        if entry.isDirectory {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            return
        }
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw DocumentStoreError.fileOperationFailed("Eine Backup-Datei konnte nicht angelegt werden.")
        }

        do {
            let archive = try FileHandle(forReadingFrom: archiveURL)
            let output = try FileHandle(forWritingTo: outputURL)
            defer {
                try? archive.close()
                try? output.close()
            }
            try archive.seek(toOffset: entry.localHeaderOffset)
            let header = try archive.read(upToCount: 30) ?? Data()
            guard header.count == 30,
                  try header.uint32LE(at: 0) == 0x0403_4B50,
                  try header.uint16LE(at: 8) == entry.compressionMethod else {
                throw DocumentStoreError.damagedDocument("Ein ZIP-Dateikopf ist beschädigt.")
            }
            let nameLength = UInt64(try header.uint16LE(at: 26))
            let extraLength = UInt64(try header.uint16LE(at: 28))
            try archive.seek(
                toOffset: entry.localHeaderOffset + 30 + nameLength + extraLength
            )

            var remaining = entry.compressedSize
            var written: UInt64 = 0
            var checksum: UInt32 = 0xFFFF_FFFF
            let writeChunk: (Data?) throws -> Void = { data in
                guard let data, !data.isEmpty else { return }
                written += UInt64(data.count)
                guard written <= entry.uncompressedSize else {
                    throw DocumentStoreError.damagedDocument("Eine ZIP-Datei expandiert über ihre deklarierte Größe.")
                }
                checksum = crc32(data, initial: checksum)
                try output.write(contentsOf: data)
            }

            if entry.compressionMethod == 0 {
                while remaining > 0 {
                    let count = Int(min(1_024 * 1_024, remaining))
                    guard let chunk = try archive.read(upToCount: count), chunk.count == count else {
                        throw DocumentStoreError.damagedDocument("Eine ZIP-Datei endet unerwartet.")
                    }
                    remaining -= UInt64(chunk.count)
                    try writeChunk(chunk)
                }
            } else {
                let filter = try OutputFilter(
                    .decompress,
                    using: .zlib,
                    bufferCapacity: 64 * 1_024,
                    writingTo: writeChunk
                )
                while remaining > 0 {
                    let count = Int(min(1_024 * 1_024, remaining))
                    guard let chunk = try archive.read(upToCount: count), chunk.count == count else {
                        throw DocumentStoreError.damagedDocument("Eine ZIP-Datei endet unerwartet.")
                    }
                    remaining -= UInt64(chunk.count)
                    try filter.write(chunk)
                }
                try filter.finalize()
            }
            try output.synchronize()
            guard written == entry.uncompressedSize,
                  checksum ^ 0xFFFF_FFFF == entry.checksum else {
                throw DocumentStoreError.damagedDocument("Die ZIP-Prüfsumme stimmt nicht.")
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }

    private static func crc32(_ data: Data, initial: UInt32) -> UInt32 {
        var crc = initial
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc
    }

    private static let crcTable: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? 0xEDB8_8320 ^ (crc >> 1) : crc >> 1
        }
        return crc
    }
}

private extension Data {
    func uint16LE(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw DocumentStoreError.damagedDocument("Das ZIP ist abgeschnitten.")
        }
        return UInt16(self[index(startIndex, offsetBy: offset)])
            | UInt16(self[index(startIndex, offsetBy: offset + 1)]) << 8
    }

    func uint32LE(at offset: Int) throws -> UInt32 {
        UInt32(try uint16LE(at: offset)) | UInt32(try uint16LE(at: offset + 2)) << 16
    }
}

enum ExportSupport {
    static func libraryBackup(store: DocumentStore) async throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotes-Exporte", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let packageURL = try await store.createLibraryBackup(in: directory)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let archiveURL = directory.appendingPathComponent(
            "BirdNotes-Backup-\(formatter.string(from: Date())).zip"
        )
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(
            readingItemAt: packageURL,
            options: .forUploading,
            error: &coordinationError
        ) { uploadURL in
            do {
                try FileManager.default.copyItem(at: uploadURL, to: archiveURL)
            } catch {
                copyError = error
            }
        }
        if let copyError { throw copyError }
        if let coordinationError {
            throw DocumentStoreError.fileOperationFailed(coordinationError.localizedDescription)
        }
        return archiveURL
    }

    static func notebookPDF(
        pages: [NotebookPage],
        title: String,
        fileSuffix: String? = nil
    ) throws -> URL {
        guard !pages.isEmpty else {
            throw DocumentStoreError.fileOperationFailed("Das Notizbuch enthält keine Seite.")
        }
        let firstBounds = pdfBounds(
            for: pages[0].metadata.paperFormat,
            orientation: pages[0].metadata.paperOrientation
        )
        let renderer = UIGraphicsPDFRenderer(bounds: firstBounds)
        let data = renderer.pdfData { context in
            for page in pages {
                let bounds = pdfBounds(
                    for: page.metadata.paperFormat,
                    orientation: page.metadata.paperOrientation
                )
                context.beginPage(withBounds: bounds, pageInfo: [:])
                drawNotebookPage(page, in: context.cgContext, destination: bounds)
            }
        }
        return try write(data, named: exportName(title, suffix: fileSuffix, extension: "pdf"))
    }

    static func notebookPagePNG(_ page: NotebookPage, title: String, pageNumber: Int) throws -> URL {
        let pageSize = page.metadata.pageSize
        let renderer = UIGraphicsImageRenderer(
            size: pageSize,
            format: UIGraphicsImageRendererFormat.preferred()
        )
        let image = renderer.image { context in
            drawNotebookPage(
                page,
                in: context.cgContext,
                destination: CGRect(origin: .zero, size: pageSize)
            )
        }
        guard let data = image.pngData() else {
            throw DocumentStoreError.fileOperationFailed("Die PNG-Datei konnte nicht erzeugt werden.")
        }
        return try write(data, named: exportName(title, suffix: "Seite-\(pageNumber)", extension: "png"))
    }

    static func annotatedPDF(
        document: PDFDocument,
        drawings: [Int: PKDrawing],
        title: String
    ) throws -> URL {
        guard let firstPage = document.page(at: 0) else {
            throw DocumentStoreError.fileOperationFailed("Die PDF-Datei enthält keine Seite.")
        }
        let renderer = UIGraphicsPDFRenderer(bounds: firstPage.bounds(for: .mediaBox))
        let data = renderer.pdfData { context in
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                let cgContext = context.cgContext
                cgContext.saveGState()
                UIColor.white.setFill()
                cgContext.fill(bounds)
                page.draw(with: .mediaBox, to: cgContext)
                cgContext.restoreGState()

                if let drawing = drawings[index], !drawing.strokes.isEmpty {
                    let image = drawing.image(from: bounds, scale: 2)
                    image.draw(in: bounds)
                }
            }
        }
        return try write(data, named: exportName(title, suffix: "mit-Notizen", extension: "pdf"))
    }

    private static func drawNotebookPage(
        _ page: NotebookPage,
        in context: CGContext,
        destination: CGRect
    ) {
        context.saveGState()
        UIColor.white.setFill()
        context.fill(destination)
        drawPaperStyle(page.metadata.paperStyle, in: context, destination: destination)

        if let drawing = try? PKDrawing(data: page.drawingData), !drawing.strokes.isEmpty {
            let source = CGRect(origin: .zero, size: page.metadata.pageSize)
            drawing.image(from: source, scale: 2).draw(in: destination)
        }
        context.restoreGState()
    }

    private static func drawPaperStyle(
        _ style: PaperStyle,
        in context: CGContext,
        destination: CGRect
    ) {
        guard style != .blank else { return }
        let spacing = destination.width / 32
        context.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.16).cgColor)
        context.setLineWidth(max(destination.width / 2_000, 0.35))

        if style == .dotted {
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.22).cgColor)
            let radius = max(destination.width / 1_500, 0.65)
            var x = spacing
            while x < destination.width {
                var y = spacing
                while y < destination.height {
                    context.fillEllipse(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    y += spacing
                }
                x += spacing
            }
            return
        }

        let summaryTop = style == .cornell ? destination.height * 0.82 : destination.height
        var y = spacing
        while y < summaryTop {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: destination.width, y: y))
            y += spacing
        }
        if style == .grid {
            var x = spacing
            while x < destination.width {
                context.move(to: CGPoint(x: x, y: 0))
                context.addLine(to: CGPoint(x: x, y: destination.height))
                x += spacing
            }
        } else if style == .cornell {
            let cueColumnX = destination.width * 0.28
            context.move(to: CGPoint(x: cueColumnX, y: 0))
            context.addLine(to: CGPoint(x: cueColumnX, y: summaryTop))
            context.move(to: CGPoint(x: 0, y: summaryTop))
            context.addLine(to: CGPoint(x: destination.width, y: summaryTop))
        }
        context.strokePath()
    }

    private static func pdfBounds(
        for format: PaperFormat,
        orientation: PaperOrientation
    ) -> CGRect {
        let portraitBounds = switch format {
        case .a4: CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        case .a3: CGRect(x: 0, y: 0, width: 841.89, height: 1_190.55)
        }
        guard orientation == .landscape else { return portraitBounds }
        return CGRect(
            x: 0,
            y: 0,
            width: portraitBounds.height,
            height: portraitBounds.width
        )
    }

    private static func write(_ data: Data, named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BirdNotes-Exporte", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func exportName(_ title: String, suffix: String?, extension pathExtension: String) -> String {
        let cleanTitle = sanitized(title)
        let suffixPart = suffix.map { "-\(sanitized($0))" } ?? ""
        return "\(cleanTitle)\(suffixPart).\(pathExtension)"
    }

    private static func sanitized(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return value.components(separatedBy: invalid).joined(separator: "-")
    }
}

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
