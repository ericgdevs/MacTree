import Foundation
import SQLite3

class Migrations {
    private let db: SQLiteDatabase
    
    init(db: SQLiteDatabase) {
        self.db = db
    }
    
    func run() throws {
        let currentVersion = try getCurrentVersion()
        logInfo("Current schema version: \(currentVersion)")
        
        if currentVersion == 0 {
            // Fresh database - run initial migration
            try runInitialMigration()
            logInfo("Initial migration completed")
        } else {
            // Future migrations would go here
            logInfo("Schema is up to date")
        }
    }
    
    private func getCurrentVersion() throws -> Int {
        // Check if schema_version table exists
        let checkSQL = """
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='schema_version'
        """
        
        guard let stmt = try db.prepare(checkSQL) else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) != SQLITE_ROW {
            return 0 // Table doesn't exist
        }
        
        // Get current version
        let versionSQL = "SELECT MAX(version) FROM schema_version"
        guard let versionStmt = try db.prepare(versionSQL) else {
            return 0
        }
        defer { sqlite3_finalize(versionStmt) }
        
        if sqlite3_step(versionStmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(versionStmt, 0))
        }
        
        return 0
    }
    
    private func runInitialMigration() throws {
        // Read migrations.sql from Resources/Database
        guard let migrationPath = Bundle.module.path(forResource: "Database/migrations", ofType: "sql") else {
            throw DatabaseError.migrationFailed(message: "migrations.sql not found")
        }
        
        let migrationSQL = try String(contentsOfFile: migrationPath, encoding: .utf8)
        
        // Execute migration in transaction
        try db.beginTransaction()
        do {
            // Split by semicolon and execute each statement
            let statements = migrationSQL.components(separatedBy: ";")
            logDebug("Total statement blocks: \(statements.count)")
            var statementNum = 0
            for statement in statements {
                // Remove comments while preserving the SQL structure
                var cleanLines: [String] = []
                for line in statement.components(separatedBy: .newlines) {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    // Skip comment-only lines
                    if !trimmedLine.starts(with: "--") && !trimmedLine.isEmpty {
                        cleanLines.append(line)
                    }
                }
                
                let cleanSQL = cleanLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                if cleanSQL.isEmpty {
                    continue
                }
                
                statementNum += 1
                let preview = cleanSQL.prefix(80).replacingOccurrences(of: "\n", with: " ")
                logDebug("Executing statement #\(statementNum): \(preview)...")
                do {
                    try db.execute(cleanSQL)
                    logDebug("✓ Statement #\(statementNum) succeeded")
                } catch {
                    logError("Failed statement #\(statementNum):")
                    logError("SQL: \(cleanSQL)")
                    logError("Error: \(error)")
                    throw error
                }
            }
            try db.commit()
            logInfo("Initial migration completed successfully - \(statementNum) statements executed")
        } catch {
            try db.rollback()
            throw DatabaseError.migrationFailed(message: "Migration error: \(error.localizedDescription)")
        }
    }
}
