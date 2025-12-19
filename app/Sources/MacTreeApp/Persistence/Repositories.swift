import Foundation
import SQLite3

class SessionRepository {
    private let db: SQLiteDatabase
    
    init(db: SQLiteDatabase) {
        self.db = db
    }
    
    func createSession(rootPath: String) throws -> Int64 {
        let sql = """
        INSERT INTO scan_sessions (root_path, started_at, status)
        VALUES (?, datetime('now'), 'running')
        """
        
        guard let stmt = try db.prepare(sql) else {
            throw DatabaseError.prepareFailed(message: "Failed to prepare session insert", sql: sql)
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, rootPath, -1, nil)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: "Failed to insert session", sql: sql)
        }
        
        return db.lastInsertRowId()
    }
    
    func updateSessionStatus(sessionId: Int64, status: String, totalItems: Int? = nil, totalSize: Int64? = nil, errorCount: Int? = nil) throws {
        var sql = "UPDATE scan_sessions SET status = ?, finished_at = datetime('now')"
        if totalItems != nil { sql += ", total_items = ?" }
        if totalSize != nil { sql += ", total_size = ?" }
        if errorCount != nil { sql += ", error_count = ?" }
        sql += " WHERE id = ?"
        
        guard let stmt = try db.prepare(sql) else {
            throw DatabaseError.prepareFailed(message: "Failed to prepare status update", sql: sql)
        }
        defer { sqlite3_finalize(stmt) }
        
        var bindIndex: Int32 = 1
        sqlite3_bind_text(stmt, bindIndex, status, -1, nil)
        bindIndex += 1
        
        if let items = totalItems {
            sqlite3_bind_int(stmt, bindIndex, Int32(items))
            bindIndex += 1
        }
        if let size = totalSize {
            sqlite3_bind_int64(stmt, bindIndex, size)
            bindIndex += 1
        }
        if let errors = errorCount {
            sqlite3_bind_int(stmt, bindIndex, Int32(errors))
            bindIndex += 1
        }
        
        sqlite3_bind_int64(stmt, bindIndex, sessionId)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: "Failed to update session", sql: sql)
        }
    }
    
    func setLastSessionId(_ sessionId: Int64) throws {
        let sql = """
        INSERT OR REPLACE INTO app_state (key, value, updated_at)
        VALUES ('last_session_id', ?, datetime('now'))
        """
        
        guard let stmt = try db.prepare(sql) else {
            throw DatabaseError.prepareFailed(message: "Failed to prepare app state update", sql: sql)
        }
        defer { sqlite3_finalize(stmt) }
        
        sqlite3_bind_text(stmt, 1, String(sessionId), -1, nil)
        
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(message: "Failed to update last session", sql: sql)
        }
    }
    
    func getLastSessionId() throws -> Int64? {
        let sql = "SELECT value FROM app_state WHERE key = 'last_session_id'"
        
        guard let stmt = try db.prepare(sql) else {
            throw DatabaseError.prepareFailed(message: "Failed to prepare last session query", sql: sql)
        }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            let valueStr = String(cString: sqlite3_column_text(stmt, 0))
            if let sessionId = Int64(valueStr), sessionId > 0 {
                return sessionId
            }
        }
        
        return nil
    }
}

class FileEntryRepository {
    private let db: SQLiteDatabase
    
    init(db: SQLiteDatabase) {
        self.db = db
    }
    
    func insertBatch(sessionId: Int64, entries: [FileEntry]) throws {
        let sql = """
        INSERT INTO file_entries (session_id, path, name, parent_path, type, size, mtime, extension)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        guard let stmt = try db.prepare(sql) else {
            throw DatabaseError.prepareFailed(message: "Failed to prepare entry insert", sql: sql)
        }
        defer { sqlite3_finalize(stmt) }
        
        try db.beginTransaction()
        
        do {
            for entry in entries {
                sqlite3_reset(stmt)
                sqlite3_bind_int64(stmt, 1, sessionId)
                sqlite3_bind_text(stmt, 2, (entry.path as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 3, (entry.name as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if let parent = entry.parentPath {
                    sqlite3_bind_text(stmt, 4, (parent as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(stmt, 4)
                }
                sqlite3_bind_text(stmt, 5, (entry.type.rawValue as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_int64(stmt, 6, entry.size)
                if let mtime = entry.mtime {
                    let formatter = ISO8601DateFormatter()
                    let timeStr = formatter.string(from: mtime)
                    sqlite3_bind_text(stmt, 7, (timeStr as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                if let ext = entry.extension {
                    sqlite3_bind_text(stmt, 8, (ext as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                } else {
                    sqlite3_bind_null(stmt, 8)
                }
                
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    let errorMsg = String(cString: sqlite3_errmsg(db.handle))
                    let errorCode = sqlite3_errcode(db.handle)
                    throw DatabaseError.executionFailed(message: "Failed to insert entry: [\(errorCode)] \(errorMsg)", sql: sql)
                }
            }
            
            try db.commit()
        } catch {
            try db.rollback()
            throw error
        }
    }
}

class DirAggregateRepository {
    private let db: SQLiteDatabase
    
    init(db: SQLiteDatabase) {
        self.db = db
    }
    
    func upsertBatch(sessionId: Int64, aggregates: [DirAggregate]) throws {
        let sql = """
        INSERT INTO dir_aggregates (session_id, path, total_size, file_count, dir_count, depth)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(session_id, path) DO UPDATE SET
            total_size = excluded.total_size,
            file_count = excluded.file_count,
            dir_count = excluded.dir_count,
            depth = excluded.depth
        """
        
        guard let stmt = try db.prepare(sql) else {
            throw DatabaseError.prepareFailed(message: "Failed to prepare aggregate upsert", sql: sql)
        }
        defer { sqlite3_finalize(stmt) }
        
        try db.beginTransaction()
        
        do {
            for aggregate in aggregates {
                sqlite3_reset(stmt)
                sqlite3_bind_int64(stmt, 1, sessionId)
                sqlite3_bind_text(stmt, 2, aggregate.path, -1, nil)
                sqlite3_bind_int64(stmt, 3, aggregate.totalSize)
                sqlite3_bind_int(stmt, 4, Int32(aggregate.fileCount))
                sqlite3_bind_int(stmt, 5, Int32(aggregate.dirCount))
                sqlite3_bind_int(stmt, 6, Int32(aggregate.depth))
                
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.executionFailed(message: "Failed to upsert aggregate", sql: sql)
                }
            }
            
            try db.commit()
        } catch {
            try db.rollback()
            throw error
        }
    }
}
