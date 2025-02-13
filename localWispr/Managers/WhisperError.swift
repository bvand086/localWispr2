import Foundation

public enum WhisperError: Error {
    case transcriptionFailed(String)
    case invalidAudioFormat
} 