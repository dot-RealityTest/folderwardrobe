import Darwin
import AppKit
import Foundation

enum ExtendedAttributeStore {
    static func readData(name: String, at url: URL) throws -> Data? {
        try withPath(url) { path in
            errno = 0
            let size = getxattr(path, name, nil, 0, 0, 0)
            if size == -1 {
                if errno == ENOATTR || errno == ENODATA {
                    return nil
                }
                throw FolderColorError.xattrOperationFailed(name: name, code: errno)
            }

            if size == 0 {
                return Data()
            }

            var data = Data(count: size)
            let result = data.withUnsafeMutableBytes { buffer in
                getxattr(path, name, buffer.baseAddress, size, 0, 0)
            }

            if result == -1 {
                throw FolderColorError.xattrOperationFailed(name: name, code: errno)
            }

            return data
        }
    }

    static func writeData(_ data: Data?, name: String, at url: URL) throws {
        try withPath(url) { path in
            if let data {
                let result = data.withUnsafeBytes { buffer in
                    setxattr(path, name, buffer.baseAddress, data.count, 0, 0)
                }

                if result == -1 {
                    throw FolderColorError.xattrOperationFailed(name: name, code: errno)
                }
            } else {
                let result = removexattr(path, name, 0)
                if result == -1, errno != ENOATTR, errno != ENODATA {
                    throw FolderColorError.xattrOperationFailed(name: name, code: errno)
                }
            }
        }
    }

    private static func withPath<T>(_ url: URL, _ body: (UnsafePointer<CChar>) throws -> T) throws -> T {
        try url.withUnsafeFileSystemRepresentation { pointer in
            guard let pointer else {
                throw CocoaError(.fileReadInvalidFileName)
            }
            return try body(pointer)
        }
    }
}

enum FinderCommentStore {
    static let attributeName = "com.apple.metadata:kMDItemFinderComment"

    static func read(at url: URL) throws -> String? {
        guard let data = try ExtendedAttributeStore.readData(name: attributeName, at: url) else {
            return nil
        }

        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        if let comment = plist as? String {
            return comment
        }

        if let comments = plist as? [String] {
            return comments.first
        }

        return nil
    }

    static func write(_ comment: String?, to url: URL) throws {
        let trimmed = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            try ExtendedAttributeStore.writeData(nil, name: attributeName, at: url)
            return
        }

        let data = try PropertyListSerialization.data(fromPropertyList: trimmed, format: .binary, options: 0)
        try ExtendedAttributeStore.writeData(data, name: attributeName, at: url)
    }
}

enum FinderTagStore {
    static let attributeName = "com.apple.metadata:_kMDItemUserTags"

    static func read(at url: URL) throws -> [String] {
        guard let data = try ExtendedAttributeStore.readData(name: attributeName, at: url) else {
            return []
        }

        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let storedTags = plist as? [String] else {
            return []
        }

        return storedTags
            .map { entry in
                if let rawTag = entry.split(separator: "\n").first {
                    return String(rawTag)
                }
                return entry
            }
            .filter { !$0.isEmpty }
    }

    static func write(_ tags: [String], to url: URL) throws {
        let cleanedTags = tags
            .map { $0.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedTags.isEmpty else {
            try ExtendedAttributeStore.writeData(nil, name: attributeName, at: url)
            return
        }

        let data = try PropertyListSerialization.data(fromPropertyList: cleanedTags, format: .binary, options: 0)
        try ExtendedAttributeStore.writeData(data, name: attributeName, at: url)
    }
}

enum CustomMetadataStore {
    static let customizationAttribute = "com.foldercolor.customization.v1"
    static let maxCustomizationBytes = 120_000

    static func readCustomization(at url: URL) throws -> PersistedCustomization? {
        guard let data = try ExtendedAttributeStore.readData(name: customizationAttribute, at: url) else {
            return nil
        }

        return try JSONDecoder().decode(PersistedCustomization.self, from: data)
    }

    static func readRawCustomizationData(at url: URL) throws -> Data? {
        try ExtendedAttributeStore.readData(name: customizationAttribute, at: url)
    }

    static func writeCustomization(_ customization: PersistedCustomization, to url: URL) throws {
        let data = try compactCustomizationData(for: customization)
        try ExtendedAttributeStore.writeData(data, name: customizationAttribute, at: url)
    }

    static func writeRawCustomizationData(_ data: Data?, to url: URL) throws {
        if let data, data.count > maxCustomizationBytes {
            throw FolderColorError.metadataTooLarge("customization")
        }
        try ExtendedAttributeStore.writeData(data, name: customizationAttribute, at: url)
    }

    private static func compactCustomizationData(for customization: PersistedCustomization) throws -> Data {
        let encoder = JSONEncoder()
        var candidate = customization

        func encodedData() throws -> Data {
            try encoder.encode(candidate)
        }

        var data = try encodedData()
        if data.count <= maxCustomizationBytes {
            return data
        }

        if let iconData = candidate.customIconData, let image = NSImage(data: iconData) {
            for maxEdge in [512, 384, 320, 256, 192, 160, 128, 96, 80, 64] {
                if let resized = image.pngData(maxDimension: CGFloat(maxEdge)) {
                    candidate.customIconData = resized
                    data = try encodedData()
                    if data.count <= maxCustomizationBytes {
                        return data
                    }
                }
            }
        }

        candidate.customIconData = nil
        if candidate.replacementMode == .customFile {
            candidate.replacementMode = .none
        }

        data = try encodedData()
        if data.count <= maxCustomizationBytes {
            return data
        }

        candidate.finderComment = String(candidate.finderComment.prefix(512))
        candidate.tags = Array(candidate.tags.prefix(20))
        data = try encodedData()

        guard data.count <= maxCustomizationBytes else {
            throw FolderColorError.metadataTooLarge("customization")
        }

        return data
    }
}
