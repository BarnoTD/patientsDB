import Foundation
import GRDB

struct DBInfo: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var lastModified: Int64
    var dbVersion: String?
    
    // Define the table name
    static var databaseTableName: String { "dbinfo" }
    
    // Define the columns
    enum Columns {
        static let id = Column("id")
        static let lastModified = Column("lastmodified")
        static let dbVersion = Column("dbversion")
    }
}
