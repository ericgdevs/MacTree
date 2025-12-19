import Foundation

struct FileEntry {
    let path: String
    let name: String
    let parentPath: String?
    let type: EntryType
    let size: Int64
    let mtime: Date?
    let `extension`: String?
    
    enum EntryType: String {
        case file
        case directory
        case symlink
    }
    
    var isDirectory: Bool {
        return type == .directory
    }
}
