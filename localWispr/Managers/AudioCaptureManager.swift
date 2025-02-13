import AVFoundation
import SwiftUI

// Import WhisperError and WhisperManager
@_exported import Foundation

// Add this error definition at the top of the file
public enum WhisperError: Error {
    case invalidAudioFormat
    case audioCaptureError
    case permissionDenied
}

/// Manages audio capture for macOS using AVAudioEngine
public class AudioCaptureManager: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputBuffer: [Float] = []
    private var whisperManager: WhisperManager
    
    @Published public var isRecording = false
    
    public init() {
        // Direct file system access (development only)
        let modelURL = URL(fileURLWithPath: "/Users/vandeben/Documents/localWispr/Resources/ggml-base.en.bin")
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            fatalError("Whisper model not found at path: \(modelURL.path)")
        }
        
        do {
            self.whisperManager = try WhisperManager(modelURL: modelURL)
        } catch {
            fatalError("Failed to initialize WhisperManager: \(error)")
        }
        
        // On macOS, still ensure microphone access is requested/available
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                print("Microphone permission not granted.")
            }
        }
    }
    
    public func startRecording() throws {
        // --- 1) Use the input node's *output* format to see how the hardware is feeding the engine.
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // --- 2) Define the desired audio format (16kHz mono PCM Float32)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: 16000,
                                          channels: 1,
                                          interleaved: false)!
        
        // --- 3) Validate the format for Whisper
        let isValidFormat = (desiredFormat.sampleRate == 16000 &&
                           desiredFormat.channelCount == 1 &&
                           desiredFormat.commonFormat == .pcmFormatFloat32)
        guard isValidFormat else {
            throw WhisperError.invalidAudioFormat
        }
        
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
                // Handle stream end if needed
            }
            else if status == .error || error != nil {
                // Handle conversion errors if needed
            }
        }
        
        // --- 6) Start the audio engine
        try engine.start()
        isRecording = true
    }
    
    public func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }
    
    public func getAudioFrames() -> [Float] {
        return inputBuffer
    }
} 
