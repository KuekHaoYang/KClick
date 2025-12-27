//
//  KClickApp.swift
//  KClick
//
//  Created by Hao Yang Kuek on 27/12/2025.
//

import SwiftUI
import Combine

@main
struct KClickApp: App {
    @StateObject private var clickManager = ClickManager()
    @StateObject private var shortcutManager = ShortcutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(clickManager)
                .environmentObject(shortcutManager)
                .onAppear {
                    shortcutManager.onTriggerStarted = {
                        if clickManager.clickMode == .toggle {
                            clickManager.toggle()
                        } else {
                            clickManager.start()
                        }
                    }
                    
                    shortcutManager.onTriggerEnded = {
                        if clickManager.clickMode == .hold {
                            clickManager.stop()
                        }
                    }
                }
                .onReceive(shortcutManager.$isFnPressed) { isPressed in
                    clickManager.setPaused(isPressed)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
