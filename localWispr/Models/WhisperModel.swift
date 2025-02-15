import Foundation

struct WhisperModel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let info: String
    let url: URL
    let filename: String
    
    var isDownloaded: Bool {
        let modelPath = Self.modelsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
    
    static let defaultModels: [WhisperModel] = [
        WhisperModel(
            name: "base.en",
            info: "(F16, 142 MiB)",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!,
            filename: "ggml-base.en.bin"
        ),
        WhisperModel(
            name: "tiny.en",
            info: "(F16, 75 MiB)",
            url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin")!,
            filename: "ggml-tiny.en.bin"
        )
    ]
    
    static var modelsDirectory: URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Application Support directory")
        }
        
        let bundleID = Bundle.main.bundleIdentifier ?? "bvdw.localWispr"
        let modelsDirURL = appSupportURL.appendingPathComponent(bundleID).appendingPathComponent("models")
        
        if !fileManager.fileExists(atPath: modelsDirURL.path) {
            do {
                try fileManager.createDirectory(at: modelsDirURL, withIntermediateDirectories: true)
            } catch {
                fatalError("Could not create models directory: \(error)")
            }
        }
        
        return modelsDirURL
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WhisperModel, rhs: WhisperModel) -> Bool {
        lhs.id == rhs.id
    }
} 