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

    private var textView: NSTextView!
    private var scrollView: NSScrollView!

    private let maxLines = 2000
    private let trimChunk = 500
    private var lineCount = 0

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

        textView = LogTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.allowsUndo = false
        textView.usesFindBar = false

        scrollView.documentView = textView
        window!.contentView!.addSubview(scrollView)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
        window?.makeFirstResponder(textView)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func windowDidBecomeKey(_ notification: Notification) {
        window?.makeFirstResponder(textView)
    }

    func appendLog(_ raw: String) {
        let clean = stripANSI(raw)
        let lines = clean.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard !lines.isEmpty, let storage = textView.textStorage else { return }

        let stickToBottom = isScrolledToBottom()

        let batch = NSMutableAttributedString()
        for line in lines {
            batch.append(colorize(line))
            batch.append(NSAttributedString(string: "\n"))
        }

        storage.append(batch)
        lineCount += lines.count

        trimIfNeeded()

        if stickToBottom {
            textView.scrollToEndOfDocument(nil)
        }
    }

    private func isScrolledToBottom() -> Bool {
        let clip = scrollView.contentView
        let docHeight = textView.frame.height
        if docHeight <= clip.bounds.height { return true }
        let visibleMaxY = clip.bounds.origin.y + clip.bounds.height
        return visibleMaxY >= docHeight - 40
    }

    private func trimIfNeeded() {
        guard lineCount > maxLines, let storage = textView.textStorage else { return }

        let toRemove = max(trimChunk, lineCount - maxLines)
        let nsString = storage.string as NSString

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
            lineCount -= found
        }
    }

    func clearLogs() {
        textView.string = ""
        lineCount = 0
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
