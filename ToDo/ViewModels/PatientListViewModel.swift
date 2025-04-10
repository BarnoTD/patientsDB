//
//  PatientListViewModel.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//


import Foundation
import Dependencies
import GoogleDriveClient
import UniformTypeIdentifiers

@MainActor
class PatientListViewModel: ObservableObject,DatabaseManagerDelegate {
    @Published private(set) var patients: [Patient] = []
    @Dependency(\.googleDriveClient) var client
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isAddButtonDisabled = false
    @Published var errorMessage: String?
    
    init() {
        DatabaseManager.shared.delegate = self
        loadPatients()
    }
    
    //    func loadPatients() async {
    //        do {
    //            patients = try DatabaseManager.shared.fetchAllPatients()
    //        } catch {
    //            print("Error loading patients: \(error)")
    //        }
    //    }
    
    
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
    
    func pushDatabase() async {
        do {
            // Get the Documents directory URL
            let fileManager = FileManager.default
            let dbURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("PatientManager", isDirectory: true).appendingPathComponent("db.sqlite")
            
            
            // Read the file's data
            let data = try Data(contentsOf: dbURL)
            
            let name = dbURL.lastPathComponent
            
            // Upload the SQLite file to Google Drive
            let file = try await client.createFile(
                name: name,
                spaces: "appDataFolder",
                mimeType: "application/x-sqlite3",
                parents: ["appDataFolder"],
                data: data
            )
            print("File uploaded successfully: \(file.id)")
            
        } catch {
            print("CreateFile failure: \(error)")
            errorMessage = "Failed to upload file: \(error.localizedDescription)"
        }
    }
    
    func pullDatabase() async {
        var filesList : FilesList? = nil
        do {
            filesList = try await client.listFiles {
                $0.query = "trashed=false"
                $0.spaces = [.appDataFolder]
            }
            print("Files listed successfully: \(filesList?.files.count ?? 0) files found")
        } catch {
            print("ListFiles failure: \(error)")
            errorMessage = "Failed to list files: \(error.localizedDescription)"
        }
        
        if let filesList {
            if filesList.files.isEmpty {
                print("no backups found")
            } else {
                let file = filesList.files[0]
                do {
                    // Get the file data from Google Drive
                    let data = try await client.getFileData(fileId: file.id)
                    print("File data retrieved for download: \(data.count) bytes")
                    
                    // Get the document directory (which we have write access to)
                    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let fileURL = documentDirectory.appendingPathComponent(file.name)
                    
                    // Write the data to the file in Documents directory
                    try data.write(to: fileURL)
                    print("File successfully downloaded to: \(fileURL.path)")
                    
                    // Success alert with file location
                    print("File successfully downloaded to the app's Documents folder.\n\nPath: \(fileURL.path)'")
                    
                } catch {
                    print("DownloadFile failure: \(error)")
                    errorMessage = "Error downloading file: \(error.localizedDescription)"
                }
            }
        }
        
    }
    
    
    func didEncounterDatabaseError(_ error: Error) {
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
            print(patient.id)
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
    }
    
    func deletePatient(_ patient: Patient) async {
        if let index = patients.firstIndex(where: { $0.id == patient.id }) {
            do {
                try DatabaseManager.shared.deletePatient(patients[index])
                patients.remove(at: index)
            } catch {
                print("Error deleting patient: \(error)")
            }
        }
    }
    
}
