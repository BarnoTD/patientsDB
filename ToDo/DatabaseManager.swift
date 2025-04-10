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
        }
    }
    
    func exportToDocuments() throws -> URL  {
        // Step 1: Ensure the database pool is initialized
            guard let dbPool = dbPool else {
                throw DatabaseError.databaseNotInitialized
            }
            
            // Step 2: Get the Documents directory URL
            let fileManager = FileManager.default
            let documentsURL = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            // Step 3: Define the destination URL and path
            let destinationURL = documentsURL.appendingPathComponent("db.sqlite")
            let destinationPath = destinationURL.path
            
            // Step 4: Remove any existing file at the destination to ensure a fresh copy
            if fileManager.fileExists(atPath: destinationPath) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            // Step 5: Configure the destination database, applying encryption if needed
            var destinationConfig = Configuration()
            if isEncrypted {
                destinationConfig.prepareDatabase { db in
                    try db.usePassphrase(self.encryptionKey)
                }
            }
            
            // Step 6: Create a new DatabasePool at the destination path
            let destinationDB = try DatabasePool(path: destinationPath, configuration: destinationConfig)
            
            // Step 7: Perform the backup from the source to the destination
            try dbPool.backup(to: destinationDB)
            
            // Step 8: Return the URL of the exported file
            return destinationURL
    }
    
    // CRUD Operations
    func savePatient(_ patient: Patient) throws -> Patient {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        var patient = patient
        try dbPool.write { db in
            try patient.save(db)
        }
        return patient
    }
    
    func deletePatient(_ patient: Patient) throws {
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        try dbPool.write { db in
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
        guard let dbPool = dbPool else {
            throw DatabaseError.databaseNotInitialized
        }
        return try dbPool.read { db in
            try Patient.fetchOne(db, key: id)
        }
    }
}

enum DatabaseError: Error {
    case databaseNotInitialized
}


