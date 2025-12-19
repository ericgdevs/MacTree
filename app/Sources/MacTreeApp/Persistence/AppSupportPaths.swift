import Foundation

struct AppSupportPaths {
    static func databasePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        
        let appDir = appSupport.appendingPathComponent("MacTree", isDirectory: true)
        return appDir.appendingPathComponent("mactree.db").path
    }
}
