import Foundation
import Combine
import GoogleSignIn
import GoogleAPIClientForREST_Drive

// MARK: - Cloud Sync Errors
enum CloudSyncError: LocalizedError {
    case userNotSignedIn
    case fileNotFound
    case invalidMetadata
    case downloadFailed
    case syncInProgress
    case databaseError
    
    var errorDescription: String? {
        switch self {
        case .userNotSignedIn:
            return "User is not signed in to Google Drive"
        case .fileNotFound:
            return "Database file not found in Google Drive"
        case .invalidMetadata:
            return "Invalid file metadata received"
        case .downloadFailed:
            return "Failed to download database file"
        case .syncInProgress:
            return "Sync operation already in progress"
        case .databaseError:
            return "Error accessing local database"
        }
    }
}

// MARK: - Cloud Sync Manager
class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    private var timer: Timer?
    private let syncInterval: TimeInterval = 30 // 30 seconds
    private var isSyncing = false
    private var driveHelper: GoogleDriveHelper?
    
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncStatus: String = "Not synced"
    @Published private(set) var isEnabled: Bool = false
    
    private init() {}
    
    private func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.syncStatus = status
        }
    }
    
    private func updateLastSyncDate() {
        DispatchQueue.main.async {
            self.lastSyncDate = Date()
        }
    }
    
    private func updateIsEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.isEnabled = enabled
        }
    }
    
    // Call this after successful Google sign-in
    func initializeWithUser(_ user: GIDGoogleUser) {
        print("Initializing CloudSyncManager with user: \(user.profile?.email ?? "unknown")")
        driveHelper = GoogleDriveHelper(user: user)
        updateStatus("Ready to sync")
    }
    
    func startAutoSync() {
        print("Starting auto sync...")
        stopAutoSync() // Stop any existing timer
        
        guard let driveHelper = driveHelper else {
            print("❌ Cannot start sync - Drive helper not initialized. Call initializeWithUser first.")
            updateStatus("Error: Not initialized with Google user")
            return
        }
        
        print("✅ Starting sync timer")
        updateIsEnabled(true)
        
        timer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
        
        // Perform initial sync immediately
        Task {
            await performSync()
        }
    }
    
    func stopAutoSync() {
        print("Stopping auto sync...")
        timer?.invalidate()
        timer = nil
        updateIsEnabled(false)
    }
    
    // Call this manually to perform a one-time sync
    func manualSync() async {
        guard driveHelper != nil else {
            print("❌ Cannot perform manual sync - Drive helper not initialized")
            updateStatus("Error: Not initialized with Google user")
            return
        }
        
        await performSync()
    }
    
    private func performSync() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress")
            return
        }
        
        guard let driveHelper = driveHelper else {
            print("❌ Drive helper not initialized")
            updateStatus("Error: Drive helper not initialized")
            return
        }
        
        isSyncing = true
        updateStatus("Syncing...")
        print("🔄 Starting sync process...")
        
        do {
            // First, get the local database's last modified timestamp
            let localLastModified = try DatabaseManager.shared.getDatabaseLastModifiedTimestamp()
            print("📱 Local database last modified: \(localLastModified)")
            
            // Use the existing driveHelper to list files
            let files = await withCheckedContinuation { (continuation: CheckedContinuation<[GTLRDrive_File]?, Never>) in
                driveHelper.listFiles { files, error in
                    if let error = error {
                        print("❌ Error listing files: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: files)
                }
            }
            
            guard let files = files, let file = files.first, let fileId = file.identifier else {
                print("❌ No database file found in Drive")
                throw CloudSyncError.fileNotFound
            }
            
            print("✅ Found file with ID: \(fileId)")
            
            // Get file metadata to check last modified time
            let metadata = await withCheckedContinuation { (continuation: CheckedContinuation<GTLRDrive_File?, Never>) in
                driveHelper.getFileMetadata(fileId: fileId) { file, error in
                    if let error = error {
                        print("❌ Error getting metadata: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: file)
                }
            }
            
            guard let metadata = metadata,
                  let properties = metadata.properties else {
                print("❌ Invalid metadata or properties missing")
                throw CloudSyncError.invalidMetadata
            }
            
            print("📊 File properties: \(properties)")
            
            guard let lastModifiedStr = properties.additionalProperty(forName: "lastModified") as? String,
                  let cloudLastModified = Int64(lastModifiedStr) else {
                print("❌ Could not get lastModified from properties")
                throw CloudSyncError.invalidMetadata
            }
            
            print("☁️ Cloud last modified: \(cloudLastModified)")
            print("📱 Local last modified: \(localLastModified)")
            
            // Only sync if cloud version is newer
            if cloudLastModified > localLastModified {
                print("🔄 Cloud version is newer, downloading...")
                
                // Download the file using the helper
                let fileData = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                    driveHelper.downloadFile(fileId: fileId) { data, error in
                        if let error = error {
                            print("❌ Error downloading file: \(error.localizedDescription)")
                            continuation.resume(returning: nil)
                            return
                        }
                        continuation.resume(returning: data)
                    }
                }
                
                guard let fileData = fileData else {
                    print("❌ Failed to download file data")
                    throw CloudSyncError.downloadFailed
                }
                
                // Create a temporary file
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempURL = tempDirectory.appendingPathComponent("temp_db_\(UUID().uuidString).sqlite")
                
                do {
                    // Write the data to a temporary file
                    try fileData.write(to: tempURL)
                    print("✅ File successfully downloaded to: \(tempURL.path)")
                    
                    // Replace local database with cloud version
                    print("🔄 Replacing local database...")
                    try DatabaseManager.shared.replaceDatabase(withNewFileAt: tempURL)
                    updateLastSyncDate()
                    updateStatus("Last synced: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))")
                    
                    // Notify UI to refresh
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: NSNotification.Name("DatabaseUpdated"), object: nil)
                    }
                    
                    // Clean up
                    try? FileManager.default.removeItem(at: tempURL)
                } catch {
                    print("❌ Error writing file or replacing database: \(error.localizedDescription)")
                    throw error
                }
            } else {
                print("ℹ️ Local database is up to date")
                updateStatus("Database is up to date")
            }
        } catch {
            print("❌ Sync error: \(error.localizedDescription)")
            updateStatus("Error: \(error.localizedDescription)")
        }
        
        isSyncing = false
        print("🏁 Sync process completed")
    }
}

// MARK: - Google Drive Response Models
private struct GoogleDriveFileList: Codable {
    let files: [GoogleDriveFile]
}

private struct GoogleDriveFile: Codable {
    let id: String
    let name: String
}

private struct GoogleDriveFileMetadata: Codable {
    let modifiedTime: String
}
