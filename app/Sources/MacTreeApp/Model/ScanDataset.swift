import Foundation

class ScanDataset {
    var sessionId: Int64
    var rootPath: String
    var entries: [FileEntry] = []
    var aggregates: [String: DirAggregate] = [:]
    
    init(sessionId: Int64, rootPath: String) {
        self.sessionId = sessionId
        self.rootPath = rootPath
    }
    
    func addEntries(_ newEntries: [FileEntry]) {
        entries.append(contentsOf: newEntries)
    }
    
    func updateAggregates(_ newAggregates: [DirAggregate]) {
        for aggregate in newAggregates {
            aggregates[aggregate.path] = aggregate
        }
    }
    
    func getAggregate(for path: String) -> DirAggregate? {
        return aggregates[path]
    }
    
    func getEntriesInPath(_ path: String) -> [FileEntry] {
        return entries.filter { $0.parentPath == path }
    }
    
    func clear() {
        entries.removeAll()
        aggregates.removeAll()
    }
}
