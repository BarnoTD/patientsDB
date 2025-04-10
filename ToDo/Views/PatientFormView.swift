//
//  FormMode.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//


import SwiftUI

enum FormMode:Equatable {
    case add
    case edit(Patient)
    
    static func == (lhs: FormMode, rhs: FormMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add):
            return true
        case (.edit(let patient1), .edit(let patient2)):
            return patient1 == patient2  // Assumes Patient conforms to Equatable
        default:
            return false
        }
    }
}

struct PatientFormView: View {
    let mode: FormMode
    let onSave: (Patient) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var medicalRecordNumber = ""
    @State private var notes = ""
    
    init(mode: FormMode, onSave: @escaping (Patient) -> Void) {
        self.mode = mode
        self.onSave = onSave
        
        if case .edit(let patient) = mode {
            _firstName = State(initialValue: patient.firstName)
            _lastName = State(initialValue: patient.lastName)
            _dateOfBirth = State(initialValue: patient.dateOfBirth)
            _medicalRecordNumber = State(initialValue: patient.medicalRecordNumber)
            _notes = State(initialValue: patient.notes ?? "")
        }
    }
    
    var body: some View {
        HStack(alignment:.center){
            ZStack{
                Form {
                    Section(header: Text("Personal Information").font(.title)) {
                        TextField("First Name", text: $firstName)
                        TextField("Last Name", text: $lastName)
                        DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    }
                    
                    Section(header: Text("Medical Information")) {
                        TextField("Medical Record Number", text: $medicalRecordNumber)
                        Text("**Extra notes:**")
                        TextEditor(text: $notes)
                            .frame(height: 100)
                    }
#if(os(iOS))
                    Button("Cancel",role: .destructive) {
                        dismiss()
                    }
                    Button("Save") {
                        savePatient()
                    }
                    #endif
                }
            }
            .frame(width: 400)
            .navigationTitle(mode == FormMode.add ? "Add Patient" : "Edit Patient")
            
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePatient()
                }
                .disabled(!isValid)
            }
        }
#if(os(macOS))
        .frame(width: 700, height: 400) // Add this to set the initial size
#else
#endif
    }
    
    private var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !medicalRecordNumber.isEmpty
    }
    
    private func savePatient() {
        let patient = Patient(
            id: (mode == .add) ? nil : {
                if case .edit(let patient) = mode { return patient.id }
                return nil
            }(),
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            medicalRecordNumber: medicalRecordNumber,
            notes: notes.isEmpty ? nil : notes
        )
        
        onSave(patient)
        dismiss()
    }
}

#Preview {
    PatientFormView(mode: .add) { patient in
        Task {
            
        }
    }
}
