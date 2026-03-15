import Cocoa

class LogWindowController: NSWindowController, NSWindowDelegate {
    
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    
    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .resizable, NSPanel.StyleMask.utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Midnight — Logs"
        window.center()
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.alphaValue = 0.95
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        
        self.init(window: window)
        setupTextView()
        window.delegate = self
    }
    
    private func setupTextView() {
        scrollView = NSScrollView(frame: window!.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        
        textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 10)
        
        scrollView.documentView = textView
        window!.contentView!.addSubview(scrollView)
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
    
    func appendLog(_ raw: String) {
        let clean = stripANSI(raw)
        let lines = clean.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            let attributed = colorize(line)
            textView.textStorage?.append(attributed)
            textView.textStorage?.append(NSAttributedString(string: "\n"))
        }
        
        textView.scrollToEndOfDocument(nil)
    }
    
    func clearLogs() {
        textView.string = ""
    }
    
    private func stripANSI(_ text: String) -> String {
        var result = text.replacingOccurrences(
            of: "\\u{1B}(?:\\[[0-9;]*[a-zA-Z]|\\][^\\u{07}]*\\u{07})",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "\\[[0-9;]+m",
            with: "",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: "[+-]\\d{4}\\s",
            with: "",
            options: .regularExpression
        )
        return result
    }
    
    private func colorize(_ line: String) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        let color: NSColor
        
        if line.contains("FATAL") || line.contains("ERROR") {
            color = .systemRed
        } else if line.contains("WARN") {
            color = .systemOrange
        } else if line.contains("INFO") {
            color = .systemGreen
        } else if line.contains("DEBUG") {
            color = .systemBlue
        } else {
            color = .labelColor
        }
        
        return NSAttributedString(string: line, attributes: [
            .foregroundColor: color,
            .font: font
        ])
    }
}