import Cocoa
import WebKit

class MainWindowController: NSWindowController {
    private var webViewBridge: WebViewBridge?
    
    init() {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MacTree"
        window.minSize = NSSize(width: 800, height: 600)
        
        super.init(window: window)
        
        // Setup WebView
        let config = WKWebViewConfiguration()
        let preferences = WKPreferences()
        config.preferences = preferences
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.allowsMagnification = false
        
        // Disable default context menu
        if #available(macOS 13.3, *) {
            webView.isInspectable = false
        }
        
        window.contentView?.addSubview(webView)
        
        // Layout constraints
        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: contentView.topAnchor),
                webView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }
        
        // Initialize bridge
        webViewBridge = WebViewBridge(webView: webView)
        
        // Load UI
        webViewBridge?.loadUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
}
