import Foundation
import GRDB

// MARK: - Database Protocol
protocol DatabaseManaging {
    func savePatient(_ patient: Patient) throws -> Patient
    func deletePatient(_ patient: Patient) throws
    func loadPatients(completion: @escaping (Result<[Patient], Error>) -> Void)
    func fetchPatient(id: Int64) throws -> Patient?
    func exportToDocuments() throws -> URL
    func pushDatabaseToCloud() async throws
    func replaceDatabase(withNewFileAt newFileURL: URL) throws
}

protocol DatabaseManagerDelegate: AnyObject {
    func didEncounterDatabaseError(_ error: Error)
}

// MARK: - Database Errors
enum DatabaseError: LocalizedError {
    case databaseNotInitialized
    case dbInfoNotFound
    case readFailed
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .databaseNotInitialized:
            return "Database has not been initialized"
        case .dbInfoNotFound:
            return "Database info not found"
        case .readFailed:
            return "Failed to read from database"
        case .invalidConfiguration:
            return "Invalid database configuration"
        }
    }
}

// MARK: - Database Manager
class DatabaseManager: DatabaseManaging {
    static let shared = DatabaseManager()
    private var dbPool: DatabasePool?
    private let encryptionKey: String
    private var isEncrypted: Bool
    weak var delegate: DatabaseManagerDelegate?
    
    private init() {
        // In a real app, this should be loaded from a secure configuration
        self.encryptionKey = ProcessInfo.processInfo.environment["DB_ENCRYPTION_KEY"] ?? "passTest"
        self.isEncrypted = true
        setupDatabase()
    }
    
    func toggleEncryption() throws {
        isEncrypted.toggle()
        setupDatabase()
    }
    
    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let folderURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("PatientManager", isDirectory: true)
            
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            let dbURL = folderURL.appendingPathComponent("db.sqlite")
            
            var configuration = Configuration()
            if isEncrypted {
                configuration.prepareDatabase { db in
                    try db.usePassphrase(self.encryptionKey)
                }
            }
            
            dbPool = try DatabasePool(path: dbURL.path, configuration: configuration)
            
            try migrateDatabaseIfNeeded()
        } catch {
            dbPool = nil
            delegate?.didEncounterDatabaseError(error)
        }
    }
    
    func replaceDatabase(withNewFileAt newFileURL: URL) throws {
        print("🔄 Starting database replacement process...")
        
        guard FileManager.default.fileExists(atPath: newFileURL.path) else {
            print("❌ Source file does not exist at: \(newFileURL.path)")
            throw DatabaseError.invalidConfiguration
        }
        
        // Check file size to ensure it's a valid database
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: newFileURL.path)
        let fileSize = fileAttributes[.size] as? UInt64 ?? 0
        print("📊 Source file size: \(fileSize) bytes")
        
        guard fileSize > 0 else {
            print("❌ Source file is empty")
            throw DatabaseError.invalidConfiguration
        }
        
        let fileManager = FileManager.default
        let folderURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("PatientManager", isDirectory: true)
        let currentDbURL = folderURL.appendingPathComponent("db.sqlite")
        let currentWalURL = folderURL.appendingPathComponent("db.sqlite-wal")
        let currentShmURL = folderURL.appendingPathComponent("db.sqlite-shm")
        
        print("📁 Current database path: \(currentDbURL.path)")
        
        // Close current connection
        print("🔄 Closing current database connection...")
        self.dbPool = nil
        
        // Remove existing WAL and SHM files
        if fileManager.fileExists(atPath: currentWalURL.path) {
            try fileManager.removeItem(at: currentWalURL)
            print("✅ Removed WAL file")
        }
        
        if fileManager.fileExists(atPath: currentShmURL.path) {
            try fileManager.removeItem(at: currentShmURL)
            print("✅ Removed SHM file")
        }
        
        // Replace database file
        if fileManager.fileExists(atPath: currentDbURL.path) {
            try fileManager.removeItem(at: currentDbURL)
            print("✅ Removed old database file")
        }
        
        // Create a copy instead of moving to avoid issues with different volumes
        try fileManager.copyItem(at: newFileURL, to: currentDbURL)
        print("✅ Copied new database file to destination")
        
        // Verify the new database exists
        guard fileManager.fileExists(atPath: currentDbURL.path) else {
            print("❌ Failed to copy database file to destination")
            throw DatabaseError.invalidConfiguration
        }
        
        // Reinitialize
        print("🔄 Reinitializing database connection...")
        setupDatabase()
        
        // Verify database connection
        guard dbPool != nil else {
            print("❌ Failed to reconnect to database")
            throw DatabaseError.databaseNotInitialized
        }
        
        print("✅ Database replacement completed successfully")
    }
    
    private func migrateDatabaseIfNeeded() throws {
        try dbPool?.write { db in
            try db.create(table: "patients", ifNotExists: true) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("firstName", .text).notNull()
                table.column("lastName", .text).notNull()
                table.column("dateOfBirth", .date).notNull()
                table.column("medicalRecordNumber", .text).notNull().unique()
                table.column("notes", .text)
            }
            try db.create(table: "dbinfo", ifNotExists: true) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("lastmodified", .integer).notNull().unique()
                table.column("dbversion", .text).defaults(to: "1.0").unique()
            }
            if try DBInfo.fetchOne(db, key: 1) == nil {
                try db.execute(
                    sql: "INSERT INTO dbinfo (id, lastmodified, dbversion) VALUES (?, ?, ?)",
                    arguments: [1, Int(Date.now.timeIntervalSince1970), "1.0"]
                )
            }
        }
    }
    
    // Helper method to update dbinfo
    private func updateLastModified(db: Database) throws {
        // This is using local time currently - we'll change it to use server time
        if var dbInfo = try DBInfo.fetchOne(db, key: 1) {
            ServerTimeUtil.getServerTime { serverTime in
                guard let serverTime = serverTime else { return }
                
                do {
                    try self.dbPool?.write { db in
                        dbInfo.lastModified = Int64(serverTime.timeIntervalSince1970)
                        try dbInfo.save(db)
                    }
                } catch {
                    self.delegate?.didEncounterDatabaseError(error)
                }
            }
        } else {
            throw DatabaseError.dbInfoNotFound
        }
    }
    
    // Wrapper for write operations
    func performWrite(_ updates: @escaping (Database) throws -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let dbPool = dbPool else {
            completion(.failure(DatabaseError.databaseNotInitialized))
            return
        }
        
        // Get server time first
        ServerTimeUtil.getServerTime { [weak self] serverTime in
            guard let self = self else {
                completion(.failure(DatabaseError.databaseNotInitialized))
                return
            }
            
            // Use server time if available, otherwise fall back to local time
            let timestamp = serverTime != nil ?
            Int64(serverTime!.timeIntervalSince1970) :
            Int64(Date.now.timeIntervalSince1970)
            
            do {
                try dbPool.write { db in
                    try updates(db)
                    
                    // Update lastModified with the server timestamp
                    if var dbInfo = try DBInfo.fetchOne(db, key: 1) {
                        dbInfo.lastModified = timestamp
                        try dbInfo.save(db)
                    } else {
                        throw DatabaseError.dbInfoNotFound
                    }
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func performWriteSync(_ updates: (Database) throws -> Void) throws {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        
        try dbPool.write { db in
            try updates(db)
            
            // Update with local time as fallback
            if var dbInfo = try DBInfo.fetchOne(db, key: 1) {
                dbInfo.lastModified = Int64(Date.now.timeIntervalSince1970)
                try dbInfo.save(db)
            } else {
                throw DatabaseError.dbInfoNotFound
            }
        }
    }
    
    //    // Wrapper for read operations with dbinfo update
    //    func performRead<T>(_ value: (Database) throws -> T) throws -> T {
    //        guard let dbPool = dbPool else {
    //            throw DatabaseError.databaseNotInitialized
    //        }
    //        var result: T?
    //        try dbPool.write { db in
    //            result = try value(db)
    //            try updateLastModified(db: db)
    //        }
    //        guard let finalResult = result else {
    //            throw DatabaseError.readFailed
    //        }
    //        return finalResult
    //    }
    
    func exportToDocuments() throws -> URL {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        let fileManager = FileManager.default
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let destinationURL = documentsURL.appendingPathComponent("db.sqlite")
        let destinationPath = destinationURL.path
        if fileManager.fileExists(atPath: destinationPath) {
            try fileManager.removeItem(at: destinationURL)
        }
        var destinationConfig = Configuration()
        if isEncrypted {
            destinationConfig.prepareDatabase { db in
                try db.usePassphrase(self.encryptionKey)
            }
        }
        let destinationDB = try DatabasePool(path: destinationPath, configuration: destinationConfig)
        try dbPool.backup(to: destinationDB)
        return destinationURL
    }
    
    // CRUD Operations
    func savePatient(_ patient: Patient) throws -> Patient {
        var patient = patient
        
        // Use a semaphore to make this method synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var saveError: Error?
        
        performWrite({ db in
            try patient.save(db)
        }) { result in
            if case .failure(let error) = result {
                saveError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = saveError {
            throw error
        }
        
        return patient
    }
    
    func deletePatient(_ patient: Patient) throws {
        let semaphore = DispatchSemaphore(value: 0)
        var deleteError: Error?
        
        performWrite({ db in
            _ = try patient.delete(db)
        }) { result in
            if case .failure(let error) = result {
                deleteError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let deleteError = deleteError {
            throw deleteError
        }
    }
    
    func loadPatients(completion: @escaping (Result<[Patient], Error>) -> Void) {
        guard let dbPool = dbPool else {
            completion(.failure(DatabaseError.databaseNotInitialized))
            return
        }
        do {
            let patients = try dbPool.read { db in
                try Patient.fetchAll(db)
            }
            completion(.success(patients))
        } catch {
            completion(.failure(error))
        }
    }
    
    func fetchPatient(id: Int64) throws -> Patient? {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        return try dbPool.read { db in
            try Patient.fetchOne(db, key: id)
        }
    }
    
    func pushDatabaseToCloud() async throws {
        // Create an instance of PatientListViewModel's Google Drive helper
        let driveHelper = GoogleDriveHelper(user: GoogleSignInHelper.shared.user!)
        
        let lastModifiedTimestamp = try getDatabaseLastModifiedTimestamp()
        
        // Export the database
        let exportedURL = try exportToDocuments()
        let data = try Data(contentsOf: exportedURL)
        let name = exportedURL.lastPathComponent
        
        // Check if database file already exists in Drive
        let fileId = await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            driveHelper.queryFiles(query: "name contains 'db'") { files, error in
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                if let files = files, !files.isEmpty {
                    continuation.resume(returning: files[0].identifier)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
        
        // Create metadata with lastModified timestamp
        let properties = ["lastModified": "\(lastModifiedTimestamp)"]
        
        if let fileId = fileId {
            // File exists, update it
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                driveHelper.updateFile(fileId: fileId, data: data, mimeType: "application/x-sqlite3", properties: properties) { file, error in
                    if let file = file {
                        print("Updated file with ID: \(file.identifier ?? "unknown")")
                    } else if let error = error {
                        print("Update error: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        } else {
            // File doesn't exist, upload new one
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                driveHelper.uploadFile(data: data, name: name, mimeType: "application/x-sqlite3", toFolder: "appDataFolder", properties: properties) { file, error in
                    if let file = file {
                        print("Uploaded file with ID: \(file.identifier ?? "unknown")")
                    } else if let error = error {
                        print("Upload error: \(error.localizedDescription)")
                    }
                    continuation.resume()
                }
            }
        }
        
        
        
        // Delete the exported file after uploading
        try FileManager.default.removeItem(at: exportedURL)
    }
    
    // Add this helper function to get the lastModified timestamp
    func getDatabaseLastModifiedTimestamp() throws -> Int64 {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        
        return try dbPool.read { db in
            guard let dbInfo = try DBInfo.fetchOne(db, key: 1) else {
                throw DatabaseError.dbInfoNotFound
            }
            return dbInfo.lastModified
        }
    }
}
