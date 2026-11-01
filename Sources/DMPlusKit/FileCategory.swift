import Foundation

/// File category by extension — DMPlus's take on IDM's IDMFType table.
public enum FileCategory: String, Codable, CaseIterable, Sendable {
    case video, audio, image, document, archive, application, other

    public static func classify(fileName: String) -> FileCategory {
        classify(extension: (fileName as NSString).pathExtension.lowercased())
    }

    public static func classify(extension ext: String) -> FileCategory {
        switch ext {
        case "mp4", "mkv", "mov", "avi", "webm", "m4v", "wmv", "flv":
            return .video
        case "mp3", "aac", "flac", "wav", "ogg", "m4a", "opus":
            return .audio
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "svg", "bmp", "tiff":
            return .image
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md", "rtf", "odt", "csv":
            return .document
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg":
            return .archive
        case "app", "exe", "msi", "deb", "apk", "ipa":
            return .application
        default:
            return .other
        }
    }

    /// SF Symbol name used by the app UI for this category.
    public var symbolName: String {
        switch self {
        case .video: return "film"
        case .audio: return "music.note"
        case .image: return "photo"
        case .document: return "doc.text"
        case .archive: return "archivebox"
        case .application: return "app.badge"
        case .other: return "doc"
        }
    }
}
