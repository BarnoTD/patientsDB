import Foundation
import GRDB

protocol DatabaseManagerDelegate: AnyObject {
    func didEncounterDatabaseError(_ error: Error)
}

// MARK: - Database Manager
class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbPool: DatabasePool?
    private let encryptionKey: String = "passTest" // for testing, shouldn't keep it hardcoded
    private var isEncrypted: Bool = true
    weak var delegate: DatabaseManagerDelegate?
    
    private init() {
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
            print(dbURL.path())
            
            try migrateDatabaseIfNeeded()
        } catch {
            dbPool = nil
            delegate?.didEncounterDatabaseError(error)
        }
    }
    
    func replaceDatabase(withNewFileAt newFileURL: URL) throws {
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
        
        // Close current connection
        self.dbPool = nil
        
        // Remove existing WAL and SHM files
        try? fileManager.removeItem(at: currentWalURL)
        try? fileManager.removeItem(at: currentShmURL)
        
        // Replace database file
        if fileManager.fileExists(atPath: currentDbURL.path) {
            try fileManager.removeItem(at: currentDbURL)
        }
        try fileManager.moveItem(at: newFileURL, to: currentDbURL)
        
        // Reinitialize
        setupDatabase()
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
        if var dbInfo = try DBInfo.fetchOne(db, key: 1) {
            dbInfo.lastModified = Int64(Date.now.timeIntervalSince1970)
            try dbInfo.save(db)
        } else {
            throw DatabaseError.dbInfoNotFound
        }
    }
    
    // Wrapper for write operations
    func performWrite(_ updates: (Database) throws -> Void) throws {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        try dbPool.write { db in
            try updates(db)
            try updateLastModified(db: db)
            
        }
    }
    
    // Wrapper for read operations with dbinfo update
    func performRead<T>(_ value: (Database) throws -> T) throws -> T {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        var result: T?
        try dbPool.write { db in
            result = try value(db)
            try updateLastModified(db: db)
        }
        guard let finalResult = result else {
            throw DatabaseError.readFailed
        }
        return finalResult
    }
    
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
        try performWrite { db in
            try patient.save(db)
        }
        return patient
    }
    
    func deletePatient(_ patient: Patient) throws {
        try performWrite { db in
            _ = try patient.delete(db)
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
        return try performRead { db in
            try Patient.fetchOne(db, key: id)
        }
    }
    
    func pushDatabaseToCloud() async throws {
        // Create an instance of PatientListViewModel's Google Drive helper
        let driveHelper = GoogleDriveHelper(user: GoogleSignInHelper.shared.user!)
        
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
        
        if let fileId = fileId {
            // File exists, update it
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                driveHelper.updateFile(fileId: fileId, data: data, mimeType: "application/x-sqlite3") { file, error in
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
                driveHelper.uploadFile(data: data, name: name, mimeType: "application/x-sqlite3", toFolder: "appDataFolder") { file, error in
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
}

enum DatabaseError: Error {
    case databaseNotInitialized
    case dbInfoNotFound
    case readFailed
}
