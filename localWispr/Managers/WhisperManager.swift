import Foundation
import AVFoundation

public final class WhisperManager {
    public static let shared = WhisperManager()
    
    let modelURL: URL
    
    public init(modelURL: URL) {
        self.modelURL = modelURL
        // Initialize Whisper model here
    }
    
    public func transcribe(audioFrames: [Float]) async throws -> String {
        // Ensure we have valid audio data
        guard !audioFrames.isEmpty else {
            throw WhisperError.invalidAudioFormat
        }
        
        return await withCheckedContinuation { continuation in
            // Pass our Float array to the C function safely
            audioFrames.withUnsafeBufferPointer { buffer in
                // bridging pointer for the C function
                guard let baseAddr = buffer.baseAddress else {
                    continuation.resume(throwing: WhisperError.invalidAudioFormat)
                    return
                }
                
                // Call the C function from the bridging header
                let result = whisperTranscribe(baseAddr, Int32(buffer.count))
                
                // Check the result
                if result.hasPrefix("Error:") {
                    continuation.resume(throwing: WhisperError.transcriptionFailed(result))
                } else {
                    continuation.resume(returning: result as String)
                }
            }
        }
    }
    
    public func validateAudioFormat(_ format: AVAudioFormat) -> Bool {
        let isValid = (format.sampleRate == 16000 &&
                       format.channelCount == 1 &&
                       format.commonFormat == .pcmFormatFloat32)
        return isValid
    }
} 