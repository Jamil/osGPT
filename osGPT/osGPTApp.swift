//
//  osGPTApp.swift
//  osGPT
//
//  Created by Jamil Dhanani on 10/14/23.
//

import SwiftUI
import AVFoundation

@main
struct osGPTApp: App {
    
    init() {
        requestMicrophoneAccess()
    }
    
    func requestMicrophoneAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: // User has granted access to the microphone
            print("Authorized")
            
        case .notDetermined: // User has not yet been presented with the option to grant access to the microphone
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Access granted")
                } else {
                    print("Access denied")
                }
            }
            
        case .denied: // User has previously denied access
            print("Denied")
            
        case .restricted: // User is not allowed to access the microphone
            print("Restricted")
            
        @unknown default:
            print("Unknown authorization status")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 50)
    }
}
