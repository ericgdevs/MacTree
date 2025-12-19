import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindowController: MainWindowController?
    var database: SQLiteDatabase?
    var sessionRepo: SessionRepository?
    var fileEntryRepo: FileEntryRepository?
    var dirAggregateRepo: DirAggregateRepository?
    var currentDataset: ScanDataset?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo("MacTree application launching...")
        
        // Initialize database
        do {
            let dbPath = AppSupportPaths.databasePath()
            database = try SQLiteDatabase(path: dbPath)
            
            // Run migrations
            let migrations = Migrations(db: database!)
            try migrations.run()
            
            // Initialize repositories
            sessionRepo = SessionRepository(db: database!)
            fileEntryRepo = FileEntryRepository(db: database!)
            dirAggregateRepo = DirAggregateRepository(db: database!)
            
            // Try to load last scan
            try loadLastScan()
            
            logInfo("Database initialized successfully")
        } catch {
            logError("FATAL: Failed to initialize database: \(error)")
            logError("App cannot continue without database. Terminating.")
            NSApp.terminate(nil)
        }
        
        // Create and show main window
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        
        // Make app active
        NSApp.activate(ignoringOtherApps: true)
        
        logInfo("MacTree application ready")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logInfo("MacTree application terminating")
        database?.close()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func loadLastScan() throws {
        guard let sessionRepo = sessionRepo else { return }
        
        if let lastSessionId = try sessionRepo.getLastSessionId() {
            logInfo("Last session ID: \(lastSessionId)")
            // TODO: Load full dataset from database
            // For now, just log that we found it
        } else {
            logInfo("No previous scan found")
        }
    }
    
    // Test scan function (T023 - wire scanner prototype to print stats)
    func testScan(rootPath: String) {
        logInfo("Test scan starting for: \(rootPath)")
        
        guard let sessionRepo = sessionRepo,
              let fileEntryRepo = fileEntryRepo,
              let dirAggregateRepo = dirAggregateRepo else {
            logError("Repositories not initialized")
            return
        }
        
        let scanner = Scanner()
        let cancellationToken = ScanCancellationToken()
        let aggregator = Aggregator()
        
        do {
            // Create session
            let sessionId = try sessionRepo.createSession(rootPath: rootPath)
            logInfo("Created session: \(sessionId)")
            
            var totalItems = 0
            var totalSize: Int64 = 0
            var totalErrors = 0
            
            // Scan with callbacks
            scanner.scan(rootPath: rootPath, cancellationToken: cancellationToken) { progress, entries in
                do {
                    // Persist entries
                    try fileEntryRepo.insertBatch(sessionId: sessionId, entries: entries)
                    
                    // Update aggregates
                    let newAggregates = aggregator.processEntries(entries)
                    try dirAggregateRepo.upsertBatch(sessionId: sessionId, aggregates: newAggregates)
                    
                    // Update stats
                    totalItems = progress.itemsScanned
                    totalSize += entries.reduce(0) { $0 + $1.size }
                    totalErrors = progress.errors.count
                    
                    // Log progress
                    logInfo("Progress: \(totalItems) items, \(progress.itemsPerSecond) items/sec")
                } catch {
                    logError("Failed to persist batch: \(error)")
                }
            }
            
            // Update session status
            try sessionRepo.updateSessionStatus(
                sessionId: sessionId,
                status: cancellationToken.isCancelled ? "cancelled" : "completed",
                totalItems: totalItems,
                totalSize: totalSize,
                errorCount: totalErrors
            )
            
            // Set as last session
            try sessionRepo.setLastSessionId(sessionId)
            
            logInfo("Scan complete: \(totalItems) items, \(totalSize) bytes, \(totalErrors) errors")
            
        } catch {
            logError("Scan failed: \(error)")
        }
    }
}
