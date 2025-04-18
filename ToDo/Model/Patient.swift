import Foundation
import GRDB

// MARK: - Patient Errors
enum PatientError: LocalizedError {
    case invalidFirstName
    case invalidLastName
    case invalidMedicalRecordNumber
    case invalidDateOfBirth
    
    var errorDescription: String? {
        switch self {
        case .invalidFirstName:
            return "First name cannot be empty"
        case .invalidLastName:
            return "Last name cannot be empty"
        case .invalidMedicalRecordNumber:
            return "Medical record number must be valid"
        case .invalidDateOfBirth:
            return "Date of birth cannot be in the future"
        }
    }
}

// MARK: - Patient Model
struct Patient: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var medicalRecordNumber: String
    var notes: String?
    
    // MARK: - Computed Properties
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var age: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }
    
    // MARK: - Validation
    func validate() throws {
        guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PatientError.invalidFirstName
        }
        
        guard !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PatientError.invalidLastName
        }
        
        guard !medicalRecordNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PatientError.invalidMedicalRecordNumber
        }
        
        guard dateOfBirth <= Date() else {
            throw PatientError.invalidDateOfBirth
        }
    }
    
    // MARK: - Database Configuration
    static var databaseTableName: String { "patients" }
    
    enum Columns {
        static let id = Column("id")
        static let firstName = Column("firstName")
        static let lastName = Column("lastName")
        static let dateOfBirth = Column("dateOfBirth")
        static let medicalRecordNumber = Column("medicalRecordNumber")
        static let notes = Column("notes")
    }
}
