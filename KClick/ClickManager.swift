import Foundation
import AppKit
import CoreGraphics
import Combine

final class ClickManager: ObservableObject {
    enum ClickMode: Int, Codable, CaseIterable {
        case toggle = 0
        case hold = 1
        
        var name: String {
            switch self {
            case .toggle: return "Toggle"
            case .hold: return "Hold"
            }
        }
    }
    
    @Published var isClicking = false
    @Published var clicksPerSecond: Double = 10.0 {
        didSet { 
            saveSettings()
            updateTimer() 
        }
    }
    @Published var clickMode: ClickMode = .toggle {
        didSet { 
            saveSettings()
            stop() 
        }
    }
    @Published var isPausedByFn = false
    @Published var isMouseOverApp = false
    
    private let defaults = UserDefaults(suiteName: "com.kclick.settings") ?? .standard
    private let cpsKey = "cps"
    private let modeKey = "mode"
    
    private var isLoading = false
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        isLoading = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.defaults.object(forKey: self.cpsKey) != nil {
                self.clicksPerSecond = self.defaults.double(forKey: self.cpsKey)
            }
            let savedMode = self.defaults.integer(forKey: self.modeKey)
            if let mode = ClickMode(rawValue: savedMode) {
                self.clickMode = mode
            }
            self.isLoading = false
        }
    }
    
    private func saveSettings() {
        guard !isLoading else { return }
        defaults.set(clicksPerSecond, forKey: cpsKey)
        defaults.set(clickMode.rawValue, forKey: modeKey)
        defaults.synchronize()
    }
    
    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.kclick.clickingQueue", qos: .userInteractive)
    
    func start() {
        guard !isClicking else { return }
        isClicking = true
        updateTimer()
    }
    
    func stop() {
        isClicking = false
        stopTimer()
    }
    
    func toggle() {
        if isClicking {
            stop()
        } else {
            start()
        }
    }
    
    func setPaused(_ paused: Bool) {
        if isPausedByFn == paused { return }
        isPausedByFn = paused
        updateTimer()
    }
    
    private func updateTimer() {
        stopTimer()
        guard isClicking && !isPausedByFn else { return }
        
        // Fire the first click immediately
        simulateClick()
        
        let interval = 1.0 / max(1.0, clicksPerSecond)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.simulateClick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func simulateClick() {
        // High-precision check to avoid clicking on ourselves
        guard let currentLocation = CGEvent(source: nil)?.location else { return }
        
        // Convert CG coordinates (0,0 top-left) to Cocoa coordinates (0,0 bottom-left of screen 0)
        let screen0Height = NSScreen.screens.first?.frame.height ?? 0
        let cocoaPoint = NSPoint(x: currentLocation.x, y: screen0Height - currentLocation.y)
        
        // Find the window number under the mouse at the cocoa-level
        let winNum = NSWindow.windowNumber(at: cocoaPoint, belowWindowWithWindowNumber: 0)
        
        // If the window belongs to our app, skip clicking
        if NSApp.windows.contains(where: { $0.windowNumber == winNum }) {
            return
        }
        
        // Secondary safety check for hover state
        if isMouseOverApp { return }
        
        queue.async {
            // Re-check position to ensure we are still clicking at the current cursor
            guard let currentLocation = CGEvent(source: nil)?.location else { return }

            // Using nil source is generally more compatible across different app types
            let clickDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentLocation, mouseButton: .left)
            let clickUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: currentLocation, mouseButton: .left)
            
            // Post events to the system-wide HID tap
            clickDown?.post(tap: .cghidEventTap)
            clickUp?.post(tap: .cghidEventTap)
        }
    }
}
