import Foundation
import SQLite3

class SQLiteDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    
    // Public accessor for error messages
    var handle: OpaquePointer? {
        return db
    }
    
    // Static factory method for default database location
    static func open() throws -> SQLiteDatabase {
        let dbPath = try AppSupportPaths.databasePath()
        return try SQLiteDatabase(path: dbPath)
    }
    
    init(path: String) throws {
        self.dbPath = path
        try openDatabase()
        try configurePragmas()
    }
    
    deinit {
        close()
    }
    
    private func openDatabase() throws {
        // Create parent directory if needed
        let dbURL = URL(fileURLWithPath: dbPath)
        let parentDir = dbURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        // Open database
        let result = sqlite3_open(dbPath, &db)
        guard result == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.openFailed(message: errmsg)
        }
        logInfo("SQLite database opened at: \(dbPath)")
    }
    
    private func configurePragmas() throws {
        // Enable foreign keys
        try execute("PRAGMA foreign_keys = ON")
        
        // WAL mode for better concurrency
        try execute("PRAGMA journal_mode = WAL")
        
        // Faster syncing (reasonable durability for cache data)
        try execute("PRAGMA synchronous = NORMAL")
        
        logDebug("SQLite pragmas configured")
    }
    
    func close() {
        guard db != nil else { return }
        sqlite3_close(db)
        db = nil
        logDebug("SQLite database closed")
    }
    
    func execute(_ sql: String) throws {
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }
        
        let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(message: errmsg, sql: sql)
        }
        
        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE || stepResult == SQLITE_ROW else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.executionFailed(message: errmsg, sql: sql)
        }
    }
    
    func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.prepareFailed(message: errmsg, sql: sql)
        }
        return statement
    }
    
    func beginTransaction() throws {
        try execute("BEGIN TRANSACTION")
    }
    
    func commit() throws {
        try execute("COMMIT")
    }
    
    func rollback() throws {
        try execute("ROLLBACK")
    }
    
    func lastInsertRowId() -> Int64 {
        return sqlite3_last_insert_rowid(db)
    }
}

enum DatabaseError: Error {
    case openFailed(message: String)
    case prepareFailed(message: String, sql: String)
    case executionFailed(message: String, sql: String)
    case migrationFailed(message: String)
    case notFound
}
