//
//  ContentView.swift
//  localWispr
//
//  Created by Benjamin van der Woerd on 2025-02-13.
//

import SwiftUI
import AVFoundation
import WhisperKit

struct ContentView: View {
    @StateObject private var audioManager = AudioCaptureManager()
    @State private var transcriptionText = "Press the button or use Command+R to start recording..."
    @State private var isProcessing = false
    @State private var showingModelSelector = false
    @State private var modelError: String?
    
    private var hasModel: Bool {
        WhisperModel.defaultModels.contains { $0.isDownloaded }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !hasModel {
                VStack(spacing: 12) {
                    Text("No Whisper model found")
                        .font(.headline)
                    Text("Please download a model to start transcribing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Download Model") {
                        showingModelSelector = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(transcriptionText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                
                Button(action: {
                    Task {
                        await toggleRecording()
                    }
                }) {
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
            
            // Model management button
            Button("Manage Models") {
                showingModelSelector = true
            }
            .font(.footnote)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .sheet(isPresented: $showingModelSelector) {
            NavigationStack {
                ModelsView()
            }
        }
        .alert("Model Error", isPresented: .constant(modelError != nil)) {
            Button("OK") {
                modelError = nil
            }
        } message: {
            if let error = modelError {
                Text(error)
            }
        }
    }
    
    private func toggleRecording() async {
        if audioManager.isRecording {
            audioManager.stopRecording()
            await processAudio()
        } else {
            do {
                try await audioManager.startRecording()
                transcriptionText = "Recording... (Press the button or Command+R to stop)"
            } catch {
                transcriptionText = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
    
    private func processAudio() async {
        guard let model = WhisperModel.defaultModels.first(where: { $0.isDownloaded }) else {
            modelError = "No model available. Please download a model first."
            return
        }
        
        isProcessing = true
        let frames = audioManager.getAudioFrames()
        
        do {
            let modelURL = WhisperModel.modelsDirectory.appendingPathComponent(model.filename)
            let whisperManager = try WhisperManager(modelURL: modelURL)
            let segments = try await whisperManager.transcribe(audioFrames: frames)
            await MainActor.run {
                transcriptionText = segments.map { $0.text }.joined(separator: " ")
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

#Preview {
    ContentView()
}
