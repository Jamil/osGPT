//
//  AppChecker.swift
//  osGPT
//
//  Created by Jamil Dhanani on 10/14/23.
//

import Foundation
import Cocoa // Import Cocoa for NSAppleScript

class AppChecker {
    var frontmostAppName: String?
    private var currentAppName: String
    private var timer: Timer?
    
    init(currentAppName: String) {
        self.currentAppName = currentAppName
        setupTimer()
    }
    
    private func setupTimer() {
        // Create a Timer that fires every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .background).async {
                self?.checkFrontmostApp()
            }
        }
    }
    
    private func checkFrontmostApp() {
        // AppleScript to get the name of the frontmost application
        let appleScriptCode = """
        tell application "System Events"
            set frontmostProcess to first process where it is frontmost
            set appName to name of frontmostProcess
            return appName
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: appleScriptCode),
           let output = appleScript.executeAndReturnError(&error).stringValue {
            
            // Ignore if it's the current running app
            if output != currentAppName && output != "Xcode" {
                frontmostAppName = output
            }
            print("Frontmost App: \(frontmostAppName ?? "Unknown")")
        } else if let error = error {
            print("Error: \(error)")
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
