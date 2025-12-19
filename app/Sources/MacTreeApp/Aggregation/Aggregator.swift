import Foundation

class Aggregator {
    private var aggregates: [String: DirAggregate] = [:]
    
    func processEntries(_ entries: [FileEntry]) -> [DirAggregate] {
        var updatedAggregates: [DirAggregate] = []
        
        for entry in entries {
            // Update aggregate for each directory in the path
            var currentPath = entry.path
            var depth = 0
            
            // If this is a file, start from parent
            if !entry.isDirectory, let parent = entry.parentPath {
                currentPath = parent
                depth = pathDepth(parent)
            } else if entry.isDirectory {
                depth = pathDepth(currentPath)
            }
            
            // Propagate up the tree
            while !currentPath.isEmpty && currentPath != "/" {
                if var aggregate = aggregates[currentPath] {
                    // Update existing aggregate
                    aggregate.totalSize += entry.size
                    if !entry.isDirectory {
                        aggregate.fileCount += 1
                    } else if currentPath == entry.path {
                        aggregate.dirCount += 1
                    }
                    aggregates[currentPath] = aggregate
                } else {
                    // Create new aggregate
                    var aggregate = DirAggregate(
                        path: currentPath,
                        totalSize: entry.size,
                        fileCount: entry.isDirectory ? 0 : 1,
                        dirCount: entry.isDirectory && currentPath == entry.path ? 1 : 0,
                        depth: depth
                    )
                    aggregates[currentPath] = aggregate
                }
                
                // Move to parent
                let url = URL(fileURLWithPath: currentPath)
                let parent = url.deletingLastPathComponent().path
                if parent == currentPath {
                    break // Reached root
                }
                currentPath = parent
                depth -= 1
            }
        }
        
        // Return updated aggregates for persistence
        return Array(aggregates.values)
    }
    
    func getAggregate(for path: String) -> DirAggregate? {
        return aggregates[path]
    }
    
    func getAllAggregates() -> [DirAggregate] {
        return Array(aggregates.values)
    }
    
    func clear() {
        aggregates.removeAll()
    }
    
    private func pathDepth(_ path: String) -> Int {
        return path.components(separatedBy: "/").filter { !$0.isEmpty }.count
    }
}
