import Foundation
import AVFoundation

/// A single segment of transcribed text, along with start/end time offsets.
struct WhisperSegment {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
    
    init(text: String, start: TimeInterval, end: TimeInterval) {
        self.text = text
        self.start = start
        self.end = end
    }
}

final class WhisperManager {
    private var context: OpaquePointer?
    let modelURL: URL
    
    init(modelURL: URL) throws {
        self.modelURL = modelURL
        
        // Initialize Whisper context
        guard let context = whisperCreateContext(modelURL.path) else {
            throw WhisperError.initializationFailed
        }
        self.context = context
    }
    
    deinit {
        if let context = context {
            whisperFreeContext(context)
        }
    }
    
    /// Transcribes audio frames to an array of segments (currently only a single segment).
    /// - Parameters:
    ///   - audioFrames: Array of float audio samples (16kHz mono)
    ///   - language: Language code (default: "en")
    ///   - translate: Whether to translate to English (default: false)
    /// - Returns: Array of WhisperSegment containing the transcribed text
    /// - Throws: WhisperError if transcription fails
    func transcribe(
        audioFrames: [Float],
        language: String = "en",
        translate: Bool = false
    ) async throws -> [WhisperSegment] {
        // Ensure we have valid audio data and context
        guard !audioFrames.isEmpty else {
            throw WhisperError.invalidAudioFormat
        }
        
        guard let context = context else {
            throw WhisperError.initializationFailed
        }
        
        return await withCheckedContinuation { continuation in
            // Pass our Float array to the C function safely
            audioFrames.withUnsafeBufferPointer { buffer in
                guard let baseAddr = buffer.baseAddress else {
                    continuation.resume(throwing: WhisperError.invalidAudioFormat)
                    return
                }
                
                // Call the inference function with our stored context
                let result = whisperRunInference(
                    context,
                    baseAddr,
                    Int32(buffer.count),
                    language,
                    translate
                )
                
                // Check the result
                if result.hasPrefix("Error:") {
                    continuation.resume(throwing: WhisperError.transcriptionFailed(result))
                } else {
                    let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Create a single segment with the full text
                    let segment = WhisperSegment(text: text, start: 0, end: 0)
                    continuation.resume(returning: [segment])
                }
            }
        }
    }
    
    /// Validates that the audio format matches Whisper's requirements (16kHz mono float32)
    /// - Parameter format: The audio format to validate
    /// - Returns: True if the format is valid for Whisper
    static func validateAudioFormat(_ format: AVAudioFormat) -> Bool {
        // Whisper expects 16,000 Hz, mono audio
        guard format.sampleRate == 16000, format.channelCount == 1 else {
            return false
        }
        // Also ensure it’s PCM data (whisper needs raw PCM frames)
        let formatIsPCM = (format.commonFormat == .pcmFormatInt16 || 
                            format.commonFormat == .pcmFormatFloat32 || 
                            format.commonFormat == .pcmFormatFloat64)
        return formatIsPCM
    }
} 