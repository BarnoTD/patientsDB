//
//  PatientRepositoryProtocol.swift
//  ToDo
//
//  Created by Hold Apps on 18/4/2025.
//


import Foundation

protocol PatientRepositoryProtocol {
    func savePatient(_ patient: Patient) async throws -> Patient
    func deletePatient(_ patient: Patient) async throws
    func loadPatients() async throws -> [Patient]
    func fetchPatient(id: Int64) async throws -> Patient?
    func searchPatients(query: String) async throws -> [Patient]
}

class PatientRepository: PatientRepositoryProtocol {
    private let databaseManager: DatabaseManaging
    
    init(databaseManager: DatabaseManaging = DatabaseManager.shared) {
        self.databaseManager = databaseManager
    }
    
    func savePatient(_ patient: Patient) async throws -> Patient {
        try patient.validate()
        return try databaseManager.savePatient(patient)
    }
    
    func deletePatient(_ patient: Patient) async throws {
        try databaseManager.deletePatient(patient)
    }
    
    func loadPatients() async throws -> [Patient] {
        return try await withCheckedThrowingContinuation { continuation in
            databaseManager.loadPatients { result in
                switch result {
                case .success(let patients):
                    continuation.resume(returning: patients)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchPatient(id: Int64) async throws -> Patient? {
        try databaseManager.fetchPatient(id: id)
    }
    
    func searchPatients(query: String) async throws -> [Patient] {
        let patients = try await loadPatients()
        let searchQuery = query.lowercased()
        
        return patients.filter { patient in
            patient.firstName.lowercased().contains(searchQuery) ||
            patient.lastName.lowercased().contains(searchQuery) ||
            patient.medicalRecordNumber.lowercased().contains(searchQuery)
        }
    }
} 
