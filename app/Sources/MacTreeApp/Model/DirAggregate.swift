import Foundation

struct DirAggregate {
    let path: String
    var totalSize: Int64
    var fileCount: Int
    var dirCount: Int
    var depth: Int
    
    mutating func add(entry: FileEntry) {
        if entry.isDirectory {
            dirCount += 1
        } else {
            fileCount += 1
        }
        totalSize += entry.size
    }
}
