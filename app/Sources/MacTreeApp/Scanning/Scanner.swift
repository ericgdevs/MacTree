import Foundation

class Scanner {
    private let batchSize = 500
    private let throttleInterval: TimeInterval = 0.1 // 100ms
    
    private var cancellationToken: ScanCancellationToken?
    private var visitedSymlinks: Set<String> = []
    
    func scan(
        rootPath: String,
        cancellationToken: ScanCancellationToken,
        progressCallback: @escaping (ScanProgress, [FileEntry]) -> Void
    ) {
        self.cancellationToken = cancellationToken
        self.visitedSymlinks.removeAll()
        
        var progress = ScanProgress()
        var currentBatch: [FileEntry] = []
        var lastEmitTime = Date()
        
        logInfo("Starting scan of: \(rootPath)")
        
        // Iterative traversal using stack to avoid recursion depth issues
        var stack: [String] = [rootPath]
        
        while !stack.isEmpty {
            // Check cancellation
            if cancellationToken.isCancelled {
                logInfo("Scan cancelled")
                break
            }
            
            let currentPath = stack.removeLast()
            progress.currentPath = currentPath
            
            // Process current path
            if let entry = processPath(currentPath, progress: &progress) {
                currentBatch.append(entry)
                progress.itemsScanned += 1
                
                // Add children to stack if directory
                if entry.isDirectory {
                    if let children = getChildren(of: currentPath, progress: &progress) {
                        stack.append(contentsOf: children)
                    }
                }
            }
            
            // Emit batch if size reached or throttle interval elapsed
            let now = Date()
            if currentBatch.count >= batchSize || now.timeIntervalSince(lastEmitTime) >= throttleInterval {
                if !currentBatch.isEmpty {
                    progressCallback(progress, currentBatch)
                    currentBatch.removeAll()
                    lastEmitTime = now
                }
            }
        }
        
        // Emit final batch
        if !currentBatch.isEmpty {
            progressCallback(progress, currentBatch)
        }
        
        logInfo("Scan completed. Items: \(progress.itemsScanned), Errors: \(progress.errors.count)")
    }
    
    private func processPath(_ path: String, progress: inout ScanProgress) -> FileEntry? {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        do {
            // Get attributes without following symlinks
            let attributes = try fileManager.attributesOfItem(atPath: path)
            let fileType = attributes[.type] as? FileAttributeType
            
            // Determine entry type
            var entryType: FileEntry.EntryType = .file
            if fileType == .typeDirectory {
                entryType = .directory
            } else if fileType == .typeSymbolicLink {
                entryType = .symlink
                // Don't follow symlinks - record and skip
                visitedSymlinks.insert(path)
                logDebug("Skipping symlink: \(path)")
            }
            
            // Get size
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            
            // Get modification time
            let mtime = attributes[.modificationDate] as? Date
            
            // Get extension
            let ext = url.pathExtension.isEmpty ? nil : url.pathExtension
            
            // Get name and parent
            let name = url.lastPathComponent
            let parent = url.deletingLastPathComponent().path
            
            return FileEntry(
                path: path,
                name: name,
                parentPath: parent == path ? nil : parent,
                type: entryType,
                size: size,
                mtime: mtime,
                extension: ext
            )
            
        } catch let error as NSError {
            // Record permission/access errors
            let scanError = ScanError(
                path: path,
                errorCode: error.code,
                message: error.localizedDescription
            )
            progress.recordError(scanError)
            logDebug("Error accessing \(path): \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getChildren(of path: String, progress: inout ScanProgress) -> [String]? {
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            return contents.map { (path as NSString).appendingPathComponent($0) }
        } catch let error as NSError {
            // Record errors but continue
            let scanError = ScanError(
                path: path,
                errorCode: error.code,
                message: "Cannot read directory: \(error.localizedDescription)"
            )
            progress.recordError(scanError)
            return nil
        }
    }
}
