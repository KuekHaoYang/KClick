//
//  ContentView.swift
//  KClick
//
//  Created by Hao Yang Kuek on 27/12/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clickManager: ClickManager
    @EnvironmentObject var shortcutManager: ShortcutManager
    
    @State private var isHoveringStart = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("KClick")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Spacer()
                indicator
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Click Mode
            Picker("Mode", selection: $clickManager.clickMode) {
                ForEach(ClickManager.ClickMode.allCases, id: \.self) { mode in
                    Text(mode.name).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // CPS Control
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Clicks Per Second")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("", value: $clickManager.clicksPerSecond, format: .number)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                }
                
                Slider(value: $clickManager.clicksPerSecond, in: 1...100, step: 1)
                    .tint(.blue)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            
            // Shortcut Control
            VStack(alignment: .leading, spacing: 12) {
                Text("Trigger Shortcut")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    shortcutManager.isRecording.toggle()
                }) {
                    HStack {
                        Image(systemName: shortcutManager.isRecording ? "record.circle" : "keyboard")
                            .foregroundColor(shortcutManager.isRecording ? .red : .primary)
                        Text(shortcutManager.isRecording ? "Recording..." : (shortcutManager.currentShortcut?.descriptor ?? "Click to set"))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(shortcutManager.isRecording ? Color.red.opacity(0.1) : Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(shortcutManager.isRecording ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
                
                Text("Hold Fn to temporarily pause")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
            
            Spacer()
            
            // Start/Stop Button (Hidden in Hold Mode as hotkey handles it)
            if clickManager.clickMode == .toggle {
                Button(action: {
                    clickManager.toggle()
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(clickManager.isClicking ? Color.red : Color.blue)
                            .shadow(color: (clickManager.isClicking ? Color.red : Color.blue).opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        HStack(spacing: 12) {
                            Image(systemName: clickManager.isClicking ? "stop.fill" : "play.fill")
                                .font(.title2)
                            Text(clickManager.isClicking ? (clickManager.isPausedByFn ? "PAUSED" : "STOP") : "START")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                    }
                    .frame(height: 60)
                    .scaleEffect(isHoveringStart ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringStart)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringStart = hovering
                }
                .padding(.bottom, 24)
            } else {
                VStack {
                    Image(systemName: "hand.tap.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    Text("Hold hotkey to click")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 40)
            }
        }
        .padding()
        .frame(width: 320, height: 520)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow).ignoresSafeArea())
        .onHover { hovering in
            clickManager.isMouseOverApp = hovering
        }
    }
    
    var indicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(clickManager.isPausedByFn ? Color.orange : (clickManager.isClicking ? Color.green : Color.gray.opacity(0.5)))
                .frame(width: 8, height: 8)
                .shadow(color: clickManager.isClicking ? .green.opacity(0.5) : .clear, radius: 3)
            Text(clickManager.isPausedByFn ? "Paused" : (clickManager.isClicking ? "Active" : "Idle"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// Utility for glassmorphism effect
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    ContentView()
        .environmentObject(ClickManager())
        .environmentObject(ShortcutManager())
}
