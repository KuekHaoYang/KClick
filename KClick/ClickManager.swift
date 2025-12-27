import Foundation
import AppKit
import CoreGraphics
import Combine

final class ClickManager: ObservableObject {
    enum ClickMode: String, Codable, CaseIterable {
        case toggle = "Toggle"
        case hold = "Hold"
    }
    
    @Published var isClicking = false
    @Published var clicksPerSecond: Double = 10.0 {
        didSet { updateTimer() }
    }
    @Published var clickMode: ClickMode = .toggle {
        didSet { stop() } // Stop when mode changes to prevent confusion
    }
    @Published var isPausedByFn = false
    @Published var isMouseOverApp = false
    
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
        // Skip clicking if the mouse is over our own app window
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
