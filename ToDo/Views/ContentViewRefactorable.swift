import SwiftUI
import GoogleSignIn
import UniformTypeIdentifiers

struct ContentViewRefactorable: View {
    @ObservedObject var signInHelper = GoogleSignInHelper.shared
    @State private var fileData: DataFile? // Holds the downloaded file data
    @State private var isExporting = false // Controls the file exporter presentation
    
    var body: some View {
        VStack {
            if let user = signInHelper.user {
                // User is signed in, create GoogleDriveHelper
                let driveHelper = GoogleDriveHelper(user: user)
                
                Button("List Files") {
                    driveHelper.listFiles { files, error in
                        if let files = files {
                            print("Files: \(files.map { $0.name ?? "Unnamed" })")
                        } else if let error = error {
                            print("Error: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Download Files") {
                    downloadFile(fileId:"1EgxSSnSsOyK2u-n0mwho3seCccnUswB5D3Bfz0DMcEse4_YnCg", driveHelper: driveHelper)
                }
                .fileExporter(
                    isPresented: $isExporting,
                    document: fileData,
                    contentType: fileData?.contentType ?? .data,
                    defaultFilename: fileData?.fileName ?? "downloaded_file"
                ) { result in
                    switch result {
                    case .success(let url):
                        print("File saved to: \(url)")
                    case .failure(let error):
                        print("Export failed: \(error.localizedDescription)")
                    }
                    fileData = nil // Clear after export
                }
                
                Button("Upload Test File") {
                    let data = "Hello, Google Drive!".data(using: .utf8)!
                    driveHelper.uploadFile(data: data ,name: "test.txt", mimeType: "text/plain", toFolder: "1n2txws3_LOkF66CdrzEgm-tLdAoJxuZf7hZHd3jIaKdzBMjI7A") { file, error in
                        if let file = file {
                            print("Uploaded file with ID: \(file.identifier ?? "unknown")")
                        } else if let error = error {
                            print("Upload error: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Create Useless Folder"){
                    driveHelper.createFolder(name: "test", inFolder: "appDataFolder") { file, error in
                        if let file = file {
                            print("Files: \(file.name)")
                        } else if let error = error {
                            print("Error: \(error.localizedDescription)")
                        }
                    }
                }
                
                Button("Sign Out") {
                    signInHelper.signOut()
                }
            } else {
                // User is not signed in
                Text("Please sign in to access Google Drive")
                Button("Sign In") {
                    signInHelper.SignIn()
                }
            }
        }
    }
    
    func downloadFile(fileId: String, driveHelper: GoogleDriveHelper) {
        // Step 1: Fetch metadata
        driveHelper.getFileMetadata(fileId: fileId) { metadata, error in
            if let metadata = metadata, let mimeType = metadata.mimeType, let name = metadata.name {
                // Step 2: Download file content
                driveHelper.downloadFile(fileId: fileId) { data, error in
                    if let data = data {
                        // Step 3: Create DataFile with correct name and type
                        fileData = DataFile(data: data, fileName: name, mimeType: mimeType)
                        isExporting = true // Trigger file exporter
                    } else if let error = error {
                        print("Download error: \(error.localizedDescription)")
                    }
                }
            } else if let error = error {
                print("Metadata error: \(error.localizedDescription)")
            }
        }
    }
}



//// Struct to wrap the downloaded data for file export
//struct DataFile: FileDocument {
//    var data: Data
//    var fileName: String
//
//    static var readableContentTypes: [UTType] { [.data] }
//
//    init(data: Data, fileName: String) {
//        self.data = data
//        self.fileName = fileName
//    }
//
//    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
//        return FileWrapper(regularFileWithContents: data)
//    }
//
//    init(configuration: ReadConfiguration) throws {
//        throw CocoaError(.featureUnsupported) // Reading not needed for export
//    }
//}
