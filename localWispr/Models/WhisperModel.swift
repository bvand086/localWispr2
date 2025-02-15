import Foundation
import SwiftUI

public class WhisperModel: Identifiable, ObservableObject {
    public let id = UUID()
    public let name: String
    public let filename: String
    public let info: String
    public let url: URL
    
    @Published public private(set) var isDownloaded: Bool
    
    public init(name: String, filename: String, info: String, url: URL) {
        self.name = name
        self.filename = filename
        self.info = info
        self.url = url
        self._isDownloaded = Published(initialValue: false)
        self.checkIfDownloaded()
    }
    
    private func checkIfDownloaded() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let modelsDir = URL(fileURLWithPath: resourcePath).appendingPathComponent("models")
        let modelPath = modelsDir.appendingPathComponent(filename)
        isDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
    }
}

extension WhisperModel {
    public static let defaultModels: [WhisperModel] = [
        WhisperModel(
            name: "Tiny",
            filename: "ggml-tiny.en.bin",
            info: "Fastest, ~1GB RAM",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin")!
        ),
        WhisperModel(
            name: "Base",
            filename: "ggml-base.en.bin",
            info: "Good accuracy, ~2GB RAM",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!
        )
    ]
} 