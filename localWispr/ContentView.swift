//
//  ContentView.swift
//  localWispr
//
//  Created by Benjamin van der Woerd on 2025-02-13.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioManager = AudioCaptureManager()
    @State private var transcriptionText = "Press the button or use Command+R to start recording..."
    @State private var isProcessing = false
    @State private var microphoneAccessGranted = false
    
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(transcriptionText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title)
                    Text(audioManager.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(audioManager.isRecording ? Color.red : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isProcessing || !microphoneAccessGranted)
            .keyboardShortcut("r", modifiers: .command)
            
            if isProcessing {
                ProgressView("Processing audio...")
            }
            
            if !microphoneAccessGranted {
                VStack(spacing: 12) {
                    Text("⚠️ Microphone access is required for recording")
                        .foregroundColor(.red)
                    
                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open System Settings")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("After enabling access in System Settings, please restart the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onAppear {
            print("ContentView appeared - checking microphone permissions")
            // First check the current authorization status
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            print("Current microphone authorization status: \(status.rawValue)")
            
            switch status {
            case .notDetermined:
                print("Permission status is notDetermined - requesting access...")
                // Permission hasn't been asked yet, so ask for it
                Task {
                    // Use async/await for cleaner permission request
                    let granted = await AVCaptureDevice.requestAccess(for: .audio)
                    print("Permission request completed - granted: \(granted)")
                    print("Checking if we can access input device...")
                    
                    if let audioDevice = AVCaptureDevice.default(for: .audio) {
                        print("Found audio input device: \(audioDevice.localizedName)")
                    } else {
                        print("No audio input device found!")
                    }
                    
                    await MainActor.run {
                        microphoneAccessGranted = granted
                        transcriptionText = granted ? 
                            "Press the button or use Command+R to start recording..." :
                            "Please grant microphone access in System Settings to use the app."
                    }
                }
            case .authorized:
                // Permission was already granted
                DispatchQueue.main.async {
                    microphoneAccessGranted = true
                }
            case .denied, .restricted:
                // Permission was previously denied or restricted
                DispatchQueue.main.async {
                    microphoneAccessGranted = false
                    transcriptionText = "Microphone access is required. Please enable it in System Settings and restart the app."
                }
            @unknown default:
                break
            }
        }
    }
    
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            processAudio()
        } else {
            Task {
                do {
                    try await audioManager.startRecording()
                    await MainActor.run {
                        transcriptionText = "Recording... (Press the button or Command+R to stop)"
                    }
                } catch {
                    await MainActor.run {
                        transcriptionText = "Failed to start recording: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func processAudio() {
        isProcessing = true
        
        Task {
            do {
                let text = try await audioManager.transcribe()
                await MainActor.run {
                    transcriptionText = text
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    transcriptionText = "Transcription error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
