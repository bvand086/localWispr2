import Foundation

enum WhisperError: Error {
    case invalidAudioFormat
    case audioCaptureError
    case permissionDenied
    case initializationFailed
    case transcriptionFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidAudioFormat:
            return "Invalid audio format. Expected 16kHz mono PCM."
        case .audioCaptureError:
            return "Failed to capture audio."
        case .permissionDenied:
            return "Microphone permission denied."
        case .initializationFailed:
            return "Failed to initialize Whisper model."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
} 