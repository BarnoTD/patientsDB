import UniformTypeIdentifiers

struct DataFile: FileDocument {
    var data: Data
    var fileName: String
    var mimeType: String

    // Map MIME type to UTType for correct file extension
    var contentType: UTType {
        switch mimeType {
        case "text/plain":
            return .plainText // .txt
        case "image/jpeg":
            return .jpeg      // .jpg
        case "application/pdf":
            return .pdf       // .pdf
        case "application/json":
            return .json      // .json
        default:
            return .data      // Fallback to generic type
        }
    }

    static var readableContentTypes: [UTType] { [.data] }

    init(data: Data, fileName: String, mimeType: String) {
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported) // We’re only writing, not reading
    }
}