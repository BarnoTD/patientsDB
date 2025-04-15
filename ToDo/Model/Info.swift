import Foundation
import GRDB

struct Patient: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var medicalRecordNumber: String
    var notes: String?
    
    // Define the table name
    static var databaseTableName: String { "patients" }
    
    // Define the columns
    enum Columns {
        static let id = Column("id")
        static let firstName = Column("firstName")
        static let lastName = Column("lastName")
        static let dateOfBirth = Column("dateOfBirth")
        static let medicalRecordNumber = Column("medicalRecordNumber")
        static let notes = Column("notes")
    }
}
