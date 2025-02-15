import Foundation

public enum WhisperError: Error {
    case initializationFailed
    case invalidAudioFormat
    case audioCaptureError
    case transcriptionFailed(String)
    case permissionDenied
} 