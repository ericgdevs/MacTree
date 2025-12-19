import Foundation

// Simple logging helpers - stdout only, no telemetry per constitution

func logInfo(_ message: String) {
    print("ℹ️  [INFO] \(message)")
}

func logWarning(_ message: String) {
    print("⚠️  [WARN] \(message)")
}

func logError(_ message: String) {
    print("❌ [ERROR] \(message)")
}

func logDebug(_ message: String) {
    #if DEBUG
    print("🔍 [DEBUG] \(message)")
    #endif
}
