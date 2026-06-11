import Cocoa

final class LogTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c":
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: self, from: nil) {
                    return true
                }
            case "a":
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: self, from: nil) {
                    return true
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c":
                copy(nil)
                return
            case "a":
                selectAll(nil)
                return
            case "w":
                window?.orderOut(nil)
                return
            default:
                break
            }
        }
        super.keyDown(with: event)
    }
}

class LogWindowController: NSWindowController, NSWindowDelegate {

    private var textView: LogTextView!
    private var scrollView: NSScrollView!

    private let maxLines = 2000
    private var lines: [String] = []

    private var windowVisible = false

    convenience init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
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

        window.becomesKeyOnlyIfNeeded = false

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

        let contentSize = scrollView.contentSize

        textView = LogTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.allowsUndo = false
        textView.usesFindBar = false

        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.maxSize = NSSize(
            width: contentSize.width,
            height: .greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        window!.contentView!.addSubview(scrollView)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
        window?.makeFirstResponder(textView)

        windowVisible = true
        renderAll()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        windowVisible = false
        textView.string = ""
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) {
        window?.makeFirstResponder(textView)
    }

    func appendLog(_ raw: String) {
        let clean = stripANSI(raw)
        let newLines = clean.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !newLines.isEmpty else { return }

        lines.append(contentsOf: newLines)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }

        guard windowVisible, let storage = textView.textStorage else { return }

        let stickToBottom = isScrolledToBottom()

        let batch = NSMutableAttributedString()
        for line in newLines {
            batch.append(colorize(line))
            batch.append(NSAttributedString(string: "\n"))
        }
        storage.append(batch)

        trimViewToBuffer()

        if stickToBottom {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func renderAll() {
        guard let storage = textView.textStorage else { return }
        let full = NSMutableAttributedString()
        for line in lines {
            full.append(colorize(line))
            full.append(NSAttributedString(string: "\n"))
        }
        storage.setAttributedString(full)
        textView.scrollToEndOfDocument(nil)
    }

    private func trimViewToBuffer() {
        guard let storage = textView.textStorage else { return }
        let nsString = storage.string as NSString

        var viewLineCount = 0
        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            viewLineCount += 1
        }

        guard viewLineCount > maxLines else { return }

        let toRemove = viewLineCount - maxLines
        var found = 0
        var cutIndex = 0
        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: [.byLines, .substringNotRequired]
        ) { _, _, enclosingRange, stop in
            found += 1
            if found >= toRemove {
                cutIndex = enclosingRange.location + enclosingRange.length
                stop.pointee = true
            }
        }

        if cutIndex > 0 {
            storage.deleteCharacters(in: NSRange(location: 0, length: cutIndex))
        }
    }

    func clearLogs() {
        lines.removeAll()
        if windowVisible {
            textView.string = ""
        }
    }

    private func isScrolledToBottom() -> Bool {
        let clip = scrollView.contentView
        let docHeight = textView.frame.height
        if docHeight <= clip.bounds.height { return true }
        let visibleMaxY = clip.bounds.origin.y + clip.bounds.height
        return visibleMaxY >= docHeight - 40
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
        let font: NSFont = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
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
