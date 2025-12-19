import Foundation

struct ScanSession {
    let id: Int64
    let rootPath: String
    let volumeId: String?
    let startedAt: Date
    var finishedAt: Date?
    var status: Status
    var totalItems: Int
    var totalSize: Int64
    var errorCount: Int
    
    enum Status: String {
        case running
        case completed
        case cancelled
        case error
    }
}
