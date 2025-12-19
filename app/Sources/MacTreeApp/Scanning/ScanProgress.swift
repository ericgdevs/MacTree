import Foundation

struct ScanProgress {
    var itemsScanned: Int = 0
    var currentPath: String = ""
    var errors: [ScanError] = []
    var startTime: Date = Date()
    
    var itemsPerSecond: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 0 else { return 0 }
        return Double(itemsScanned) / elapsed
    }
    
    mutating func recordError(_ error: ScanError) {
        errors.append(error)
    }
}

struct ScanError {
    let path: String
    let errorCode: Int
    let message: String
    let timestamp: Date = Date()
}
