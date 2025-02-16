import Foundation
import SwiftUI

public enum ModelError: Error {
    case downloadFailed(String)
    case directoryCreationFailed
    case modelNotFound
}

public struct Model: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let info: String
    public let url: URL
    public let filename: String
    
    public init(name: String, info: String, url: String, filename: String) {
        self.id = name
        self.name = name
        self.info = info
        self.url = URL(string: url)!
        self.filename = filename
    }
    
    public static func == (lhs: Model, rhs: Model) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
public class ModelManager: ObservableObject {
    public static let shared = ModelManager()
    
    private static let models: [Model] = [
        Model(name: "tiny", info: "(F16, 75 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin", filename: "tiny.bin"),
        Model(name: "tiny-q5_1", info: "(31 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin", filename: "tiny-q5_1.bin"),
        Model(name: "tiny-q8_0", info: "(42 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q8_0.bin", filename: "tiny-q8_0.bin"),
        Model(name: "tiny.en", info: "(F16, 75 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin", filename: "tiny.en.bin"),
        Model(name: "tiny.en-q5_1", info: "(31 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin", filename: "tiny.en-q5_1.bin"),
        Model(name: "tiny.en-q8_0", info: "(42 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q8_0.bin", filename: "tiny.en-q8_0.bin"),
        Model(name: "base", info: "(F16, 142 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin", filename: "base.bin"),
        Model(name: "base-q5_1", info: "(57 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin", filename: "base-q5_1.bin"),
        Model(name: "base-q8_0", info: "(78 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q8_0.bin", filename: "base-q8_0.bin"),
        Model(name: "base.en", info: "(F16, 142 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin", filename: "base.en.bin"),
        Model(name: "base.en-q5_1", info: "(57 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin", filename: "base.en-q5_1.bin"),
        Model(name: "base.en-q8_0", info: "(78 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q8_0.bin", filename: "base.en-q8_0.bin"),
        Model(name: "small", info: "(F16, 466 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin", filename: "small.bin"),
        Model(name: "small-q5_1", info: "(181 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin", filename: "small-q5_1.bin"),
        Model(name: "small-q8_0", info: "(252 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q8_0.bin", filename: "small-q8_0.bin"),
        Model(name: "small.en", info: "(F16, 466 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin", filename: "small.en.bin"),
        Model(name: "small.en-q5_1", info: "(181 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q5_1.bin", filename: "small.en-q5_1.bin"),
        Model(name: "small.en-q8_0", info: "(252 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en-q8_0.bin", filename: "small.en-q8_0.bin"),
        Model(name: "medium", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin", filename: "medium.bin"),
        Model(name: "medium-q5_0", info: "(514 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q5_0.bin", filename: "medium-q5_0.bin"),
        Model(name: "medium-q8_0", info: "(785 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium-q8_0.bin", filename: "medium-q8_0.bin"),
        Model(name: "medium.en", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin", filename: "medium.en.bin"),
        Model(name: "medium.en-q5_0", info: "(514 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q5_0.bin", filename: "medium.en-q5_0.bin"),
        Model(name: "medium.en-q8_0", info: "(785 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en-q8_0.bin", filename: "medium.en-q8_0.bin"),
        Model(name: "large-v1", info: "(F16, 2.9 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large.bin", filename: "large.bin"),
        Model(name: "large-v2", info: "(F16, 2.9 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin", filename: "large-v2.bin"),
        Model(name: "large-v2-q5_0", info: "(1.1 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q5_0.bin", filename: "large-v2-q5_0.bin"),
        Model(name: "large-v2-q8_0", info: "(1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2-q8_0.bin", filename: "large-v2-q8_0.bin"),
        Model(name: "large-v3", info: "(F16, 2.9 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin", filename: "large-v3.bin"),
        Model(name: "large-v3-q5_0", info: "(1.1 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-q5_0.bin", filename: "large-v3-q5_0.bin"),
        Model(name: "large-v3-turbo", info: "(F16, 1.5 GiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin", filename: "large-v3-turbo.bin"),
        Model(name: "large-v3-turbo-q5_0", info: "(547 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin", filename: "large-v3-turbo-q5_0.bin"),
        Model(name: "large-v3-turbo-q8_0", info: "(834 MiB)", url: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin", filename: "large-v3-turbo-q8_0.bin")
    ]
    
    @Published public var isDownloading = false
    @Published public var downloadProgress: Double = 0
    @Published public var currentDownloadName: String = ""
    @Published public var errorMessage: String?
    
    public var modelsDirectory: URL {
        // Get the Documents directory
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Models", isDirectory: true)
    }
    
    public init() {
        // Create Models directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }
    
    public func getModel(named name: String) -> Model? {
        return Self.models.first { $0.name == name }
    }
    
    public func isModelDownloaded(_ model: Model) -> Bool {
        let modelURL = modelsDirectory.appendingPathComponent(model.filename)
        return FileManager.default.fileExists(atPath: modelURL.path)
    }
    
    public func downloadModel(_ model: Model) async {
        guard !isModelDownloaded(model) else { return }
        
        await MainActor.run {
            isDownloading = true
            currentDownloadName = model.name
            downloadProgress = 0
            errorMessage = nil
        }
        
        let modelURL = modelsDirectory.appendingPathComponent(model.filename)
        
        do {
            let downloadTask = URLSession.shared.downloadTask(with: model.url) { temporaryURL, response, error in
                if let error = error {
                    Task { @MainActor in
                        self.isDownloading = false
                        self.currentDownloadName = ""
                        self.downloadProgress = 0
                        self.errorMessage = "Download failed: \(error.localizedDescription)"
                    }
                    return
                }
                
                guard let response = response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode) else {
                    Task { @MainActor in
                        self.isDownloading = false
                        self.currentDownloadName = ""
                        self.downloadProgress = 0
                        self.errorMessage = "Server error: Invalid response"
                    }
                    return
                }
                
                do {
                    if let temporaryURL = temporaryURL {
                        // Simply copy the file to its destination
                        try FileManager.default.copyItem(at: temporaryURL, to: modelURL)
                        
                        Task { @MainActor in
                            self.isDownloading = false
                            self.currentDownloadName = ""
                            self.downloadProgress = 1.0
                            self.errorMessage = nil
                        }
                    }
                } catch {
                    Task { @MainActor in
                        self.isDownloading = false
                        self.currentDownloadName = ""
                        self.downloadProgress = 0
                        self.errorMessage = "Failed to save model: \(error.localizedDescription)"
                    }
                }
            }
            
            // Observe download progress
            let observation = downloadTask.progress.observe(\.fractionCompleted) { progress, _ in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                }
            }
            
            // Start the download
            downloadTask.resume()
            
            // Wait for completion
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    continuation.resume()
                }
            }
            
        } catch {
            await MainActor.run {
                isDownloading = false
                currentDownloadName = ""
                downloadProgress = 0
                errorMessage = "Failed to initiate download: \(error.localizedDescription)"
            }
        }
    }
    
    public func deleteModel(_ model: Model) {
        do {
            let modelPath = modelsDirectory.appendingPathComponent(model.filename)
            try FileManager.default.removeItem(at: modelPath)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
        }
    }
    
    public func getModelURL(for model: Model) throws -> URL {
        let modelURL = modelsDirectory.appendingPathComponent(model.filename)
        
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw ModelError.modelNotFound
        }
        
        return modelURL
    }
    
    public func downloadModelIfNeeded(modelName: String = "tiny") async throws -> URL {
        guard let model = getModel(named: modelName) else {
            throw ModelError.modelNotFound
        }
        
        let modelURL = modelsDirectory.appendingPathComponent(model.filename)
        
        // Check if model already exists
        if FileManager.default.fileExists(atPath: modelURL.path) {
            return modelURL
        }
        
        // Model doesn't exist, download it
        await downloadModel(model)
        
        // Verify the model was downloaded successfully
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw ModelError.modelNotFound
        }
        
        return modelURL
    }
    
    // Helper method to get all available models
    public static func getAllModels() -> [Model] {
        return models
    }
    
    // Helper method to get all downloaded models
    public func getDownloadedModels() -> [Model] {
        return Self.models.filter { isModelDownloaded($0) }
    }
    
    // Save the last used model name
    public func saveLastUsedModel(_ model: Model) {
        UserDefaults.standard.set(model.name, forKey: "lastUsedModelName")
    }
    
    // Get the last used model, returns nil if no model was used before
    public func getLastUsedModel() -> Model? {
        guard let modelName = UserDefaults.standard.string(forKey: "lastUsedModelName"),
              let model = getModel(named: modelName),
              isModelDownloaded(model) else {
            return nil
        }
        return model
    }
}

extension URLSession {
    func download(from url: URL, progress: @escaping (Progress) -> Void) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = self.downloadTask(with: url) { url, response, error in
                guard let url = url, let response = response else {
                    continuation.resume(throwing: error ?? URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (url, response))
            }
            
            task.progress.observe(\.fractionCompleted) { observedProgress, _ in
                progress(observedProgress)
            }
            
            task.resume()
        }
    }
} 