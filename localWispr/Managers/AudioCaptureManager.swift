import AVFoundation
import SwiftUI
import Foundation
import WhisperKit

/// Manages audio capture for macOS using AVAudioRecorder
@MainActor
public class AudioCaptureManager: ObservableObject {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL
    
    @Published public var isRecording = false
    
    public init() {
        // Create a temporary URL for recording
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording.wav")
    }
    
    /// Request microphone permissions
    /// - Returns: Bool indicating if permission was granted
    private func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
            
        case .notDetermined:
            // This will show the system permission dialog
            return await AVCaptureDevice.requestAccess(for: .audio)
            
        case .denied, .restricted:
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = "Microphone Access Required"
                alert.informativeText = "Please grant microphone access in System Settings to use this feature."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// Starts recording audio
    /// - Throws: Error if recording fails to start
    public func startRecording() async throws {
        // First check and request microphone permissions
        let permissionGranted = await requestMicrophonePermission()
        guard permissionGranted else {
            throw WhisperError.transcriptionFailed("Microphone permission denied. Please grant access in System Settings.")
        }
        
        // Set up the audio recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            #if !os(macOS)
            // Configure audio session for iOS
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            #endif
            
            // Create and configure the recorder
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder?.delegate = nil
            recorder?.prepareToRecord()
            
            // Start recording
            if recorder?.record() == false {
                throw WhisperError.transcriptionFailed("Could not start recording")
            }
            
            isRecording = true
        } catch {
            throw WhisperError.transcriptionFailed("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    public func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        
        #if !os(macOS)
        // Clean up audio session on iOS
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }
    
    public func getAudioFrames() -> [Float] {
        guard let audioFile = try? AVAudioFile(forReading: recordingURL) else {
            return []
        }
        
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return []
        }
        
        do {
            try audioFile.read(into: buffer)
            
            // Convert buffer to array of floats
            let channelData = buffer.floatChannelData?[0]
            let frames = Array(UnsafeBufferPointer(start: channelData,
                                                 count: Int(buffer.frameLength)))
            return frames
        } catch {
            print("Error reading audio file: \(error)")
            return []
        }
    }
} 
