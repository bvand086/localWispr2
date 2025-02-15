import AVFoundation
import SwiftUI
import Foundation
import WhisperKit

/// Manages audio capture for macOS using AVAudioEngine
public class AudioCaptureManager: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputBuffer: [Float] = []
    private var whisperManager: WhisperManager?
    
    @Published public var isRecording = false
    
    public init() {
        // Attempt to load the model from the app bundle
        guard let modelPath = Bundle.main.path(forResource: "ggml-base.en",
                                             ofType: "bin",
                                             inDirectory: "models") else {
            print("Error: Whisper model not found in bundle. Make sure 'ggml-base.en.bin' is in localWispr/Resources/models.")
            return
        }
        
        let modelURL = URL(fileURLWithPath: modelPath)
        do {
            self.whisperManager = try WhisperManager(modelURL: modelURL)
        } catch {
            print("Error initializing WhisperManager: \(error.localizedDescription)")
        }
        
        // Request microphone access
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                print("Microphone permission not granted.")
            }
        }
    }
    
    /// Request microphone permissions
    /// - Returns: Bool indicating if permission was granted
    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Starts recording audio, converting it to the format required by Whisper
    /// - Throws: WhisperError if format validation fails or audio engine fails to start
    public func startRecording() async throws {
        // First check and request microphone permissions
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw WhisperError.permissionDenied
        }
        
        // --- 1) Use the input node's *output* format to see how the hardware is feeding the engine.
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // --- 2) Define the desired audio format (16kHz mono PCM Float32)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16000,
                                         channels: 1,
                                         interleaved: false)!
        
        // --- 3) Prepare an AVAudioConverter from the hardware format to our desired (16kHz mono) format
        guard let converter = AVAudioConverter(from: inputFormat, to: desiredFormat) else {
            throw WhisperError.invalidAudioFormat
        }
        
        // Reset the buffer before starting
        inputBuffer.removeAll()
        
        // --- 4) Install a tap on the input node to capture audio and run it through the converter
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Prepare an output buffer in the desired format
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat,
                                                  frameCapacity: AVAudioFrameCount(buffer.frameLength))!
            
            var error: NSError?
            // Convert from the hardware buffer to our desired format
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if status == .haveData,
               let channelData = convertedBuffer.floatChannelData?[0] {
                let frameCount = Int(convertedBuffer.frameLength)
                let frames = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                self.inputBuffer.append(contentsOf: frames)
            } else if status == .endOfStream {
                print("Audio conversion: End of stream reached")
            } else if status == .error || error != nil {
                print("Audio conversion error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        do {
            // --- 5) Start the audio engine
            try engine.start()
            isRecording = true
        } catch {
            throw WhisperError.audioCaptureError
        }
    }
    
    public func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        
        #if os(iOS)
        // Clean up audio session on iOS
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }
    
    public func getAudioFrames() -> [Float] {
        return inputBuffer
    }
    
    /// Transcribes the recorded audio to text
    /// - Returns: Transcribed text as a string
    /// - Throws: WhisperError if transcription fails
    public func transcribe() async throws -> String {
        guard let whisperManager = whisperManager else {
            throw WhisperError.initializationFailed
        }
        
        let frames = getAudioFrames()
        guard !frames.isEmpty else {
            throw WhisperError.invalidAudioFormat
        }
        
        // Get segments from Whisper and combine their text
        let segments = try await whisperManager.transcribe(audioFrames: frames)
        return segments.map { $0.text }.joined(separator: " ")
    }
} 
