import Foundation

enum WhisperError: Error {
    case modelNotLoaded
    case invalidAudioFormat
    case transcriptionFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded. Please load the model first."
        case .invalidAudioFormat:
            return "Invalid audio format. Please ensure audio is in the correct format."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
} 