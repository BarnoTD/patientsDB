//
//  PatientListViewModel.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//


import Foundation
import Dependencies
import UniformTypeIdentifiers

@MainActor
class PatientListViewModel: ObservableObject,DatabaseManagerDelegate {
    @Published private(set) var patients: [Patient] = []
    @Published private var driveHelper = GoogleDriveHelper(user: GoogleSignInHelper.shared.user!)
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isAddButtonDisabled = false
    @Published var errorMessage: String?
    
    // For storing the notification observer
    private var databaseUpdatedObserver: NSObjectProtocol?
    
    init() {
        DatabaseManager.shared.delegate = self
        loadPatients()
        
        // Register for database updated notifications
        databaseUpdatedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DatabaseUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📣 Received DatabaseUpdated notification, reloading patients...")
            self?.loadPatients()
        }
    }
    
    deinit {
        // Remove observer when view model is deallocated
        if let observer = databaseUpdatedObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func loadPatients() {
        DatabaseManager.shared.loadPatients { [weak self] result in
            switch result {
            case .success(let patients):
                DispatchQueue.main.async {
                    self?.patients = patients
                    self?.isAddButtonDisabled = false
                }
            case .failure(let error):
                self?.didEncounterDatabaseError(error)
            }
        }
    }
    
    func exportDatabase() {
        do {
            try DatabaseManager.shared.exportToDocuments()
        } catch {
            errorMessage = "Export failed: \(error.localizedDescription)"
            print(errorMessage)
        }
    }
    
    func getDatabaseId() async throws -> String? {
        return await withCheckedContinuation { continuation in
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
    }
    
//    func pushDatabase() async throws {
//        do {
//            // Export the database to a complete file including WAL data
//            let exportedURL = try DatabaseManager.shared.exportToDocuments()
//
//            // Read the data from the exported file
//            let data = try Data(contentsOf: exportedURL)
//
//            // Get the file name from the exported URL
//            let name = exportedURL.lastPathComponent
//
//            // Check if database file already exists in Drive
//            let fileId = try await getDatabaseId()
//
//            if let fileId = fileId {
//                // File exists, update it
//                await withCheckedContinuation { continuation in
//                    driveHelper.updateFile(fileId: fileId, data: data, mimeType: "application/x-sqlite3") { file, error in
//                        if let file = file {
//                            print("Updated file with ID: \(file.identifier ?? "unknown")")
//                        } else if let error = error {
//                            print("Update error: \(error.localizedDescription)")
//                        }
//                        continuation.resume()
//                    }
//                }
//            } else {
//                // File doesn't exist, upload new one
//                await withCheckedContinuation { continuation in
//                    driveHelper.uploadFile(data: data, name: name, mimeType: "application/x-sqlite3", toFolder: "appDataFolder") { file, error in
//                        if let file = file {
//                            print("Uploaded file with ID: \(file.identifier ?? "unknown")")
//                        } else if let error = error {
//                            print("Upload error: \(error.localizedDescription)")
//                        }
//                        continuation.resume()
//                    }
//                }
//            }
//
//            // Delete the exported file after uploading
//            try FileManager.default.removeItem(at: exportedURL)
//        } catch {
//            print("Push database failed: \(error)")
//            errorMessage = "Failed to push database: \(error.localizedDescription)"
//        }
//    }
    
    
    func pullDatabase() async {
        driveHelper.listFiles { files, error in
            if let files = files {
                let file = files[0]
                let id = file.identifier ?? "0"
                // Step 1: Fetch metadata
                self.driveHelper.getFileMetadata(fileId: id) { metadata, error in
                    if let metadata = metadata, let mimeType = metadata.mimeType, let name = metadata.name {
                        // Step 2: Download file content
                        self.driveHelper.downloadFile(fileId: id) { data, error in
                            if let data = data {
                                do {
                                    // Save the downloaded file to the Documents folder
                                    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                                    let fileURL = documentDirectory.appendingPathComponent(file.name!)
                                    try data.write(to: fileURL)
                                    print("File successfully downloaded to: \(fileURL.path)")
                                    
                                    // Replace the current database with the new file
                                    try DatabaseManager.shared.replaceDatabase(withNewFileAt: fileURL)
                                    
                                    // Reload the patient list to reflect the new database
                                    self.loadPatients()
                                } catch {
                                    print("Error writing file or replacing database: \(error.localizedDescription)")
                                }
                            } else if let error = error {
                                print("Download error: \(error.localizedDescription)")
                            }
                        }
                    } else if let error = error {
                        print("Metadata error: \(error.localizedDescription)")
                    }
                }
            } else if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    
    func didEncounterDatabaseError(_ error: Error) {
        if let dbError = error as? DatabaseError {
            print("Database error code: \(dbError.localizedDescription)")
        }
        alertMessage = "Encryption key is wrong. We are not able to access this database."
        print(alertMessage)
        showAlert = true
        isAddButtonDisabled = true
        patients = []
    }
    
    func addPatient(_ patient: Patient) async {
        do {
            let savedPatient = try DatabaseManager.shared.savePatient(patient)
            patients.append(savedPatient)
            
            try await DatabaseManager.shared.pushDatabaseToCloud()
        } catch {
            print("Error saving patient: \(error)")
        }
    }
    
    func deletePatients(at offsets: IndexSet) async {
        for index in offsets {
            do {
                try DatabaseManager.shared.deletePatient(patients[index])
                patients.remove(at: index)
            } catch {
                print("Error deleting patient: \(error)")
            }
        }
        
        try? await DatabaseManager.shared.pushDatabaseToCloud()
    }
    
    func deletePatient(_ patient: Patient) async {
        if let index = patients.firstIndex(where: { $0.id == patient.id }) {
            do {
                try DatabaseManager.shared.deletePatient(patients[index])
                patients.remove(at: index)
                
                try await DatabaseManager.shared.pushDatabaseToCloud()
            } catch {
                print("Error deleting patient: \(error)")
            }
        }
    }
    
}
