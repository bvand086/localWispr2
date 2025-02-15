import Foundation

@MainActor
class ModelManager: ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var isDownloading = false
    @Published var currentDownloadName: String = ""
    @Published var errorMessage: String?
    
    func downloadModel(_ model: WhisperModel) async {
        guard !model.isDownloaded else { return }
        
        isDownloading = true
        currentDownloadName = model.name
        downloadProgress = 0
        errorMessage = nil
        
        let destinationURL = WhisperModel.modelsDirectory.appendingPathComponent(model.filename)
        
        do {
            let (downloadURL, _) = try await URLSession.shared.download(from: model.url) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                }
            }
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: downloadURL, to: destinationURL)
            
            await MainActor.run {
                isDownloading = false
                currentDownloadName = ""
                downloadProgress = 0
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                currentDownloadName = ""
                downloadProgress = 0
                errorMessage = "Failed to download model: \(error.localizedDescription)"
                print("Download error: \(error)")
            }
        }
    }
    
    func deleteModel(_ model: WhisperModel) {
        do {
            let modelPath = WhisperModel.modelsDirectory.appendingPathComponent(model.filename)
            try FileManager.default.removeItem(at: modelPath)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete model: \(error.localizedDescription)"
            print("Delete error: \(error)")
        }
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