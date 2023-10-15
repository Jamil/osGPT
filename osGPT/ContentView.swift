//
//  ContentView.swift
//  osGPTApp
//
//  Created by Jamil Dhanani on 10/14/23.
//

import SwiftUI
import AppKit
import AVFoundation
import Combine
import Speech

typealias GPT4Callback = (String?, Error?) -> Void

struct ContentView: View {
    @State private var input: String = ""
    @State private var output: String = ""
    @State private var executionResult: String = ""

    @State private var running: Bool = false
    
    // Speech recogntion
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var isSpeaking: Bool = false
    @State private var timer: Timer? = nil
    
    @State private var appChecker = AppChecker(currentAppName: "osGPT")
    
    func makeRequest(utterance: String) {
        running = true
        output = ""
        executionResult = ""
        
        let prompt = "Imagine you are a powerful natural language assistant which generates AppleScript for the user to control their Mac with natural language. You know AppleScript extremely well, making sure all variables are declared and the syntax is correct. The frontmost app is \(appChecker.frontmostAppName ?? "Unknown"). Do not add any extra text. Here is the natural language command: \(utterance). Give just the AppleScript."
        
        print(prompt)
        
        callGPT4API(prompt: prompt) { result, error in
            executionResult = "Executing AppleScript..."
            if let codeSnippet = result {
                let extractedSnippet = extractTextBetweenTripleBackticks(input: codeSnippet)
                let escapedSnippet = extractedSnippet.replacing("'", with: "\'")
                if let app = appChecker.frontmostAppName {
                    let precode = "tell application \"\(app)\" to activate\n\n"
                    output = precode + escapedSnippet
                } else {
                    output = escapedSnippet
                }
                DispatchQueue.global(qos: .userInitiated).async {
                    let script = "osascript -e '\(output)'"
                    let output = shell(script)
                    self.executionResult = output
                    running = false
                }
            } else {
                print("No code snippet returned")
                running = false
            }
        }
        
/*
                
 */
    }
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.gray)
                    .font(.system(size: 20))
                    .onTapGesture {
                        startSpeechRecognition()
                    }
                TextField("How can I help you?", text: $input)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                    .font(.system(size: 16))
                    .onSubmit {
                        makeRequest(utterance: input)
                    }
                    .onReceive(Just(input)) { _ in
                        if input.count == 1 {
                            output = ""
                        }
                    }
                if running {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.horizontal, 8)
                }
            }
            .padding()
            
            if output.count > 0 {
                TextEditor(text: $output)
                    .font(Font.system(.body, design: .monospaced))
                    .background(.clear)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            VisualEffectView(material: .hudWindow).opacity(0.3)
        )
    }

    struct VisualEffectView: NSViewRepresentable {
        var material: NSVisualEffectView.Material = .windowBackground
        var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

        func makeNSView(context: Context) -> NSVisualEffectView {
            return NSVisualEffectView()
        }

        func updateNSView(_ view: NSVisualEffectView, context: Context) {
            view.material = material
            view.blendingMode = blendingMode
        }
    }
    
    func callGPT4API(prompt: String, completion: @escaping GPT4Callback) {
        // The endpoint for the GPT-4 ChatCompletions API
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("Invalid URL")
            return
        }
        
        // Your API key for OpenAI's GPT-4
        let apiKey = "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"

        // Setting up the URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // The payload with the prompt and other parameters
        let payload: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ]
        ]
        
        // Convert payload to JSON data and assign to request
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(nil, error)
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let data = data else { 
                completion(nil, NSError(domain: "No data received", code: 2, userInfo: nil))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(content, nil)
                }
            } catch {
                completion(nil, error)
            }
        }
        
        task.resume()
    }
    
    func shell(_ command: String) -> String {
        let task = Process()
        let stdOutPipe = Pipe()
        let stdErrPipe = Pipe()
        task.standardOutput = stdOutPipe
        task.standardError = stdErrPipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/bash"
        task.launch()
        let data = stdOutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stdErrPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
        let errOutput = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
        task.waitUntilExit()
        return errOutput + "\n" + output
    }
    
    func startSpeechRecognition() {
        // Cleanup existing task if any
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Re-initialize the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Re-initialize the recognition task
        var lastUpdateTime: Date? = nil
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            if let result = result {
                self.input = result.bestTranscription.formattedString
                lastUpdateTime = Date()
            }

            // Cleanup when the recognition ends
            if error != nil || (result?.isFinal ?? false) {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                recognitionRequest.endAudio()
                
                // Invalidate previous timer if it exists
                self.timer?.invalidate()

                // Prepare for the next round
                DispatchQueue.main.async {
                    self.startSpeechRecognition()
                }
            }
        })

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error: \(error)")
        }

        // Timer to check for elapsed time or end of sentence
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if let lastUpdateTime = lastUpdateTime, Date().timeIntervalSince(lastUpdateTime) > 2.0 {
                timer.invalidate()
                if audioEngine.isRunning {
                    audioEngine.stop()
                    recognitionRequest.endAudio()
                    if !self.input.isEmpty {
                        makeRequest(utterance: self.input)
                    }
                    // Reset input for next command
                    self.input = ""
                }
            }
        }
    }
}


func extractTextBetweenTripleBackticks(input: String) -> String {
    // Regular expression pattern for extracting code snippet
        let pattern = "```(?:[a-zA-Z0-9]+)?\\n(.*?)\\n```"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
            if let match = regex.firstMatch(in: input, options: [], range: NSRange(location: 0, length: input.utf16.count)) {
                if let range = Range(match.range(at: 1), in: input) {
                    return String(input[range])
                }
            }
            
            // Return the entire input string if no match is found
            return input
            
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return input
        }
}

struct ContentViewPreview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
