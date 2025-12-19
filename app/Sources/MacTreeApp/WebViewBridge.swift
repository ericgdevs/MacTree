import Foundation
import WebKit
import AppKit

class WebViewBridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private weak var webView: WKWebView?
    private var currentScanCancellation: ScanCancellationToken?
    
    init(webView: WKWebView) {
        self.webView = webView
        super.init()
        webView.navigationDelegate = self
        
        // Register message handlers for JS→native communication
        webView.configuration.userContentController.add(self, name: "selectFolder")
        webView.configuration.userContentController.add(self, name: "startScan")
        webView.configuration.userContentController.add(self, name: "cancelScan")
        webView.configuration.userContentController.add(self, name: "focusPath")
        webView.configuration.userContentController.add(self, name: "revealInFinder")
    }
    
    func loadUI() {
        guard let webView = webView else { return }
        
        // Load index.html from Resources/Web
        if let htmlPath = Bundle.module.path(forResource: "Web/index", ofType: "html") {
            let url = URL(fileURLWithPath: htmlPath)
            let directoryURL = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: directoryURL)
            logInfo("Loading UI from: \(htmlPath)")
        } else {
            logError("Failed to find index.html in Resources/Web")
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        
        // Allow only file:// URLs (local resources) - no remote loads
        if url.scheme == "file" {
            decisionHandler(.allow)
        } else {
            logWarning("Blocked non-local navigation attempt: \(url)")
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logInfo("WebView finished loading")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logError("WebView navigation failed: \(error.localizedDescription)")
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        logDebug("Received message: \(message.name)")
        
        switch message.name {
        case "selectFolder":
            handleSelectFolder()
        case "startScan":
            if let params = message.body as? [String: Any],
               let path = params["path"] as? String {
                handleStartScan(path: path)
            }
        case "cancelScan":
            handleCancelScan()
        case "focusPath":
            if let params = message.body as? [String: Any],
               let path = params["path"] as? String {
                handleFocusPath(path: path)
            }
        case "revealInFinder":
            if let params = message.body as? [String: Any],
               let path = params["path"] as? String {
                handleRevealInFinder(path: path)
            }
        default:
            logWarning("Unknown message: \(message.name)")
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleSelectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                logInfo("Folder selection cancelled")
                self?.sendToJS(event: "folderSelected", data: ["cancelled": true])
                return
            }
            
            logInfo("Folder selected: \(url.path)")
            self?.sendToJS(event: "folderSelected", data: [
                "path": url.path,
                "name": url.lastPathComponent
            ])
        }
    }
    
    private func handleStartScan(path: String) {
        logInfo("Starting scan for path: '\(path)'")
        
        // Cancel any existing scan
        currentScanCancellation?.cancel()
        
        // Create new cancellation token
        let cancellation = ScanCancellationToken()
        currentScanCancellation = cancellation
        
        // Start scan on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create new session
            guard let db = try? SQLiteDatabase.open() else {
                self.sendToJS(event: "scanError", data: ["error": "Failed to open database"])
                return
            }
            
            let sessionRepo = SessionRepository(db: db)
            guard let sessionId = try? sessionRepo.createSession(rootPath: path) else {
                self.sendToJS(event: "scanError", data: ["error": "Failed to create session"])
                return
            }
            
            let fileRepo = FileEntryRepository(db: db)
            let aggRepo = DirAggregateRepository(db: db)
            let scanner = Scanner()
            let aggregator = Aggregator()
            
            var totalItems = 0
            var totalSize: Int64 = 0
            var lastProgressTime = Date()
            
            self.sendToJS(event: "scanStarted", data: ["sessionId": sessionId, "path": path])
            
            scanner.scan(rootPath: path, cancellationToken: cancellation) { [weak self] progress, entries in
                guard let self = self else { return }
                
                totalItems += entries.count
                
                // Calculate total size
                for entry in entries {
                    totalSize += entry.size
                }
                
                // Persist batch
                do {
                    try fileRepo.insertBatch(sessionId: sessionId, entries: entries)
                    
                    // Aggregate and persist
                    let aggregates = aggregator.processEntries(entries)
                    try aggRepo.upsertBatch(sessionId: sessionId, aggregates: aggregates)
                    
                    // Send progress update (throttled to ~100ms)
                    let now = Date()
                    if now.timeIntervalSince(lastProgressTime) >= 0.1 {
                        self.sendToJS(event: "scanProgress", data: [
                            "itemsScanned": totalItems,
                            "totalSize": totalSize,
                            "errors": progress.errors.count
                        ])
                        
                        // Send incremental tree data
                        self.sendIncrementalTreeData(entries: entries, aggregates: aggregates)
                        
                        lastProgressTime = now
                    }
                } catch {
                    logError("Failed to persist scan batch: \(error)")
                }
            }
            
            // Update session status
            if cancellation.isCancelled {
                _ = try? sessionRepo.updateSessionStatus(sessionId: sessionId, status: ScanSession.Status.cancelled.rawValue)
                self.sendToJS(event: "scanCancelled", data: ["sessionId": sessionId])
            } else {
                _ = try? sessionRepo.updateSessionStatus(sessionId: sessionId, status: ScanSession.Status.completed.rawValue, 
                                                         totalItems: totalItems, totalSize: totalSize)
                self.sendToJS(event: "scanCompleted", data: [
                    "sessionId": sessionId,
                    "totalItems": totalItems,
                    "totalSize": totalSize
                ])
            }
        }
    }
    
    private func handleCancelScan() {
        currentScanCancellation?.cancel()
        logInfo("Scan cancellation requested")
    }
    
    private func handleFocusPath(path: String) {
        // TODO: Phase 4 implementation
        logDebug("Focus path requested: \(path)")
    }
    
    private func handleRevealInFinder(path: String) {
        logInfo("Revealing in Finder: \(path)")
        
        let url = URL(fileURLWithPath: path)
        
        // Check if file/folder exists
        guard FileManager.default.fileExists(atPath: path) else {
            logError("Path does not exist: \(path)")
            sendToJS(event: "finderRevealError", data: ["error": "Path not found", "path": path])
            return
        }
        
        // Reveal in Finder using NSWorkspace
        NSWorkspace.shared.activateFileViewerSelecting([url])
        logInfo("Successfully revealed: \(path)")
    }
    
    // MARK: - JS Communication
    
    private func sendToJS(event: String, data: [String: Any]) {
        guard let webView = webView else { return }
        
        // Convert data to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            logError("Failed to serialize event data")
            return
        }
        
        // Properly escape the JSON string for JavaScript
        let escapedJSON = jsonString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        
        let script = "window.receiveNativeEvent(\"\(event)\", \"\(escapedJSON)\");"
        
        DispatchQueue.main.async {
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    logError("Failed to send event '\(event)' to JS: \(error)")
                } else {
                    logDebug("Sent event '\(event)' to JS")
                }
            }
        }
    }
    
    private func sendIncrementalTreeData(entries: [FileEntry], aggregates: [DirAggregate]) {
        // Convert entries to lightweight representation for JS
        let entriesData: [[String: Any]] = entries.map { entry in
            [
                "path": entry.path,
                "name": entry.name,
                "size": entry.size,
                "type": entry.type.rawValue,
                "parent": entry.parentPath ?? ""
            ]
        }
        
        let aggregatesData: [[String: Any]] = aggregates.map { agg in
            [
                "path": agg.path,
                "totalSize": agg.totalSize,
                "fileCount": agg.fileCount,
                "dirCount": agg.dirCount
            ]
        }
        
        sendToJS(event: "treeDataDelta", data: [
            "entries": entriesData,
            "aggregates": aggregatesData
        ])
    }
}
