import SwiftUI
import AppKit
import Combine

struct Shortcut: Codable, Equatable {
    enum Kind: String, Codable {
        case keyboard
        case mouse
    }
    
    var kind: Kind
    var keyCode: UInt16 // key code for keyboard, button number for mouse
    var modifiers: NSEvent.ModifierFlags.RawValue
    
    var descriptor: String {
        if kind == .mouse {
            return "Mouse Button \(keyCode)"
        }
        
        var str = ""
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { str += "⌘" }
        if flags.contains(.option) { str += "⌥" }
        if flags.contains(.control) { str += "⌃" }
        if flags.contains(.shift) { str += "⇧" }
        
        str += keyName(for: keyCode)
        return str.isEmpty ? "Not Set" : str
    }
    
    // ... (keyName and keyIdentifier remain as they were)
    private func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Space"
        case 51: return "⌫"
        case 53: return "⎋"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default:
            if let char = keyIdentifier(for: keyCode) {
                return char.uppercased()
            }
            return "K\(keyCode)"
        }
    }
    
    private func keyIdentifier(for keyCode: UInt16) -> String? {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )
        return event?.charactersIgnoringModifiers
    }
}

final class ShortcutManager: ObservableObject {
    @Published var currentShortcut: Shortcut? {
        didSet { saveShortcut() }
    }
    @Published var isRecording = false
    @Published var isFnPressed = false
    
    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []
    
    var onTriggerStarted: (() -> Void)?
    var onTriggerEnded: (() -> Void)?
    
    private var isTriggered = false
    
    init() {
        loadShortcut()
        setupMonitors()
    }
    
    private func setupMonitors() {
        // Keyboard Events
        let keyboardMask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]
        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: keyboardMask) { [weak self] event in
            self?.handleEvent(event)
        }!)
        
        localMonitors.append(NSEvent.addLocalMonitorForEvents(matching: keyboardMask) { [weak self] event in
            guard let self = self else { return event }
            if self.isRecording {
                if event.type == .keyDown {
                    self.recordKeyboardShortcut(from: event)
                    return nil
                }
            }
            self.handleEvent(event)
            return event
        }!)
        
        // Mouse Events
        let mouseMask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp
        ]
        
        globalMonitors.append(NSEvent.addGlobalMonitorForEvents(matching: mouseMask) { [weak self] event in
            self?.handleEvent(event)
        }!)
        
        localMonitors.append(NSEvent.addLocalMonitorForEvents(matching: mouseMask) { [weak self] event in
            guard let self = self else { return event }
            if self.isRecording {
                // Determine button number accurately
                let buttonNum: Int
                switch event.type {
                case .leftMouseDown: buttonNum = 0
                case .rightMouseDown: buttonNum = 1
                case .otherMouseDown: buttonNum = event.buttonNumber
                default: return event
                }
                
                // Safety: Avoid recording a simple left-click on the recording button itself
                // But allow it if it's a side button.
                if buttonNum != 0 {
                    self.recordMouseShortcut(button: buttonNum)
                    return nil
                }
            }
            self.handleEvent(event)
            return event
        }!)
    }
    
    private func handleEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            isFnPressed = event.modifierFlags.contains(.function)
            return
        }
        
        guard let shortcut = currentShortcut else { return }
        
        let isDown: Bool
        let isUp: Bool
        let match: Bool
        
        if shortcut.kind == .keyboard {
            isDown = event.type == .keyDown
            isUp = event.type == .keyUp
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            match = event.keyCode == shortcut.keyCode && modifiers == shortcut.modifiers
        } else {
            let buttonNum: Int
            switch event.type {
            case .leftMouseDown, .leftMouseUp: buttonNum = 0
            case .rightMouseDown, .rightMouseUp: buttonNum = 1
            case .otherMouseDown, .otherMouseUp: buttonNum = event.buttonNumber
            default: return
            }
            
            isDown = [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type)
            isUp = [.leftMouseUp, .rightMouseUp, .otherMouseUp].contains(event.type)
            match = buttonNum == Int(shortcut.keyCode)
        }
        
        if match {
            if isDown && !isTriggered {
                isTriggered = true
                onTriggerStarted?()
            } else if isUp {
                isTriggered = false
                onTriggerEnded?()
            }
        }
    }
    
    private func recordKeyboardShortcut(from event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        currentShortcut = Shortcut(kind: .keyboard, keyCode: event.keyCode, modifiers: modifiers)
        isRecording = false
    }
    
    private func recordMouseShortcut(button: Int) {
        currentShortcut = Shortcut(kind: .mouse, keyCode: UInt16(button), modifiers: 0)
        isRecording = false
    }
    
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: "kclick_shortcut"),
           let decoded = try? JSONDecoder().decode(Shortcut.self, from: data) {
            currentShortcut = decoded
        }
    }
    
    private func saveShortcut() {
        if let encoded = try? JSONEncoder().encode(currentShortcut) {
            UserDefaults.standard.set(encoded, forKey: "kclick_shortcut")
        }
    }
    
    deinit {
        globalMonitors.forEach { NSEvent.removeMonitor($0) }
        localMonitors.forEach { NSEvent.removeMonitor($0) }
    }
}
