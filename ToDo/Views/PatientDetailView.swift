//
//  PatientDetailView.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//


import SwiftUI

struct PatientDetailView: View {
    let patient: Patient
    let onDeselect: () -> Void // Closure to deselect the patient
    @State private var showingEditSheet = false
    @StateObject private var viewModel = PatientDetailViewModel()
    
    var body: some View {
        List {
            Section(header: Text("Personal Information")) {
                DetailRow(title: "First Name", value: patient.firstName)
                DetailRow(title: "Last Name", value: patient.lastName)
                DetailRow(title: "Date of Birth", value: patient.dateOfBirth.formatted(date: .long, time: .omitted))
            }
            
            Section(header: Text("Medical Information")) {
                DetailRow(title: "Medical Record Number", value: patient.medicalRecordNumber)
                if let notes = patient.notes {
                    Text(notes)
                        .font(.body)
                        .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Patient Details")
        .toolbar {
#if(os(macOS))
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    onDeselect()
                }) {
                    Label("Return", systemImage: "chevron.left")
                }
            }
#endif
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            PatientFormView(mode: .edit(patient)) { updatedPatient in
                Task {
                    await viewModel.updatePatient(updatedPatient)
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}


#Preview(body: {
    NavigationView{
        PatientDetailView(patient: Patient(firstName: "SA", lastName: "N", dateOfBirth: .now, medicalRecordNumber: "15"), onDeselect: {})
    }
})
