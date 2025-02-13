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
            .disabled(isProcessing)
            .keyboardShortcut("r", modifiers: .command)
            
            if isProcessing {
                ProgressView("Processing audio...")
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func toggleRecording() {
        if audioManager.isRecording {
            audioManager.stopRecording()
            processAudio()
        } else {
            do {
                try audioManager.startRecording()
                transcriptionText = "Recording... (Press the button or Command+R to stop)"
            } catch {
                transcriptionText = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    private func processAudio() {
        isProcessing = true
        let frames = audioManager.getAudioFrames()
        
        Task {
            do {
                // Initialize WhisperManager with model URL
                let modelURL = URL(fileURLWithPath: "/Users/vandeben/Documents/localWispr/Resources/ggml-base.en.bin")
                let whisperManager = try WhisperManager(modelURL: modelURL)
                let text = try await whisperManager.transcribe(audioFrames: frames)
                print("Transcription: \(text)")
                await MainActor.run {
                    transcriptionText = text.map { segment in
                        segment.text
                    }.joined()
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
