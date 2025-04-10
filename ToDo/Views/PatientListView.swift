//
//  PatientListView.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//


import SwiftUI

struct PatientListView: View {
    @StateObject private var viewModel = PatientListViewModel()
    @State private var showingAddPatient = false
    @State private var selectedPatientID: Int64? = nil
    @State private var googleSignInHelper = GoogleSignInHelper.shared
    
    var body: some View {
        NavigationView {
            // Sidebar
            List {
                ForEach(viewModel.patients) { patient in
                    HStack {
                        
#if(os(macOS))
                        NavigationLink(
                            destination: PatientDetailView(
                                patient: patient,
                                onDeselect: {
                                    selectedPatientID = nil
                                }
                            ),
                            tag: patient.id ?? 0,
                            selection: $selectedPatientID
                        ) {
                            PatientRowView(patient: patient)
                        }
                        Spacer()
                        Button("dismiss") {
                            selectedPatientID = nil
                        }
                        Button("-") {
                            selectedPatientID = nil
                            deletePatient(patient)
                        }
                        .buttonStyle(PlainButtonStyle())
                        #else
                        NavigationLink("\(patient.firstName) \(patient.lastName)") {
                            PatientDetailView(patient: patient) {
                                selectedPatientID = nil
                            }
                        }
#endif
                        
                    }
                }
                .onDelete(perform: deletePatients)
            }
            .listStyle(SidebarListStyle()) // Ensures sidebar appearance on macOS
            .navigationTitle("Patients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddPatient = true }) {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isAddButtonDisabled)
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { viewModel.exportDatabase() }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(viewModel.isAddButtonDisabled)
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        Task {
                            await viewModel.pushDatabase()
                        }
                    }){
                        Image(systemName: "cloud")
                    }
                    
                }
//                ToolbarItem(placement: .automatic) {
//                    Button("Sign Out") {
//                        googleSignInHelper.signOut()
//                    }
//                }
                ToolbarItem(placement: .automatic) {
                    Button("Import") {
                        Task{
                            await viewModel.pullDatabase()
                        }
                    }
                }
                
            }
            
            // Detail area when no patient is selected
            Text("Select a patient")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingAddPatient) {
            PatientFormView(mode: .add) { patient in
                Task {
                    await viewModel.addPatient(patient)
                }
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
                    Alert(title: Text("OOPS!"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
                }
        .task {
            await viewModel.loadPatients()
        }
    }
    
    private func deletePatients(at offsets: IndexSet) {
        Task {
            await viewModel.deletePatients(at: offsets)
        }
    }
    
    private func deletePatient(_ patient: Patient) {
        Task {
            try await Task.sleep(for: .seconds(0.5)) // 3 s
            await viewModel.deletePatient(patient)
        }
    }
}

struct PatientRowView: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(patient.lastName), \(patient.firstName)")
                .font(.headline)
            Text("MRN: #\(patient.medicalRecordNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview{
    PatientListView()
}

