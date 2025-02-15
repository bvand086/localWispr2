import AVFoundation
import SwiftUI
import Foundation

/// Manages audio capture for macOS using AVAudioEngine
final class AudioCaptureManager: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputBuffer: [Float] = []
    private var whisperManager: WhisperManager?
    
    enum WhisperError: Error {
        case initializationFailed
        case invalidAudioFormat
        case audioCaptureError
        case transcriptionFailed
        case permissionDenied
    }
    
    @Published var isRecording = false
    
    init() {
        // Direct file system access (development only)
        let modelURL = URL(fileURLWithPath: "/Users/vandeben/Documents/localWispr/Resources/ggml-base.en.bin")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            print("Error: Whisper model not found at path: \(modelURL.path)")
            return
        }
        
        do {
            self.whisperManager = try WhisperManager(modelURL: modelURL)
        } catch {
            print("Error initializing WhisperManager: \(error.localizedDescription)")
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
    func startRecording() async throws {
        // First check and request microphone permissions
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw WhisperError.permissionDenied
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .default)
        try audioSession.setActive(true)
        
        // --- 1) Use the input node's *output* format to see how the hardware is feeding the engine.
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // --- 2) Define the desired audio format (16kHz mono PCM Float32)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: 16000,
                                          channels: 1,
                                          interleaved: false)!
        
        // --- 3) Validate the format for Whisper
//        guard WhisperManager.validateAudioFormat(audioFormat) else {
//            throw WhisperError.invalidAudioFormat
//        }

        
        // --- 4) Prepare an AVAudioConverter from the hardware format to the desired (16kHz mono) format
        guard let converter = AVAudioConverter(from: inputFormat, to: desiredFormat) else {
            throw WhisperError.invalidAudioFormat
        }
        
        // Reset the buffer before starting
        inputBuffer.removeAll()
        
        // --- 5) Install a tap on the input node to capture audio and run it through the converter
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Prepare an output buffer in the desired format
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat,
                                                   frameCapacity: AVAudioFrameCount(buffer.frameLength))!
            
            var error: NSError?
            // Convert from the hardware buffer to our desired format
            let status = converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                // We have new data from the mic every time this block is invoked
                outStatus.pointee = .haveData
                return buffer
            }
            
            if status == .haveData,
               let channelData = convertedBuffer.floatChannelData?[0] {
                
                // The converter tells us how many frames ended up in convertedBuffer
                let frameCount = Int(convertedBuffer.frameLength)
                let frames = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                
                // Append to our running buffer
                self.inputBuffer.append(contentsOf: frames)
            }
            else if status == .endOfStream {
                print("Audio conversion: End of stream reached")
            }
            else if status == .error || error != nil {
                print("Audio conversion error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
        
        do {
            // --- 6) Start the audio engine
            try engine.start()
            isRecording = true
        } catch {
            throw WhisperError.audioCaptureError
        }
    }
    
    /// Stops recording audio and cleans up the audio engine
    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }
    
    /// Returns the collected audio frames
    /// - Returns: Array of float audio samples
    func getAudioFrames() -> [Float] {
        return inputBuffer
    }
    
    /// Transcribes the recorded audio to text
    /// - Returns: Transcribed text as a string
    /// - Throws: WhisperError if transcription fails
    func transcribe() async throws -> String {
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
