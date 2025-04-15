//
//  PatientDetailViewModel.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//


import Foundation

@MainActor
class PatientDetailViewModel: ObservableObject {
    func updatePatient(_ patient: Patient) async {
        do {
            _ = try DatabaseManager.shared.savePatient(patient)
            try await DatabaseManager.shared.pushDatabaseToCloud()
        } catch {
            print("Error updating patient: \(error)")
        }
    }
}
