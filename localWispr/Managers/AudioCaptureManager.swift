import AVFoundation

/// Manages audio capture for macOS using AVAudioEngine
class AudioCaptureManager: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputBuffer: [Float] = []
    @Published var isRecording = false
    private let whisperManager: WhisperManager
    
    init() {
    if let modelURL = Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin") {
        do {
            self.whisperManager = try WhisperManager(modelURL: modelURL)
        } catch {
            fatalError("Failed to initialize WhisperManager: \(error)")
        }
    } else {
        fatalError("Could not find ggml-base.en.bin in the app bundle")
    }
}

    
    func startRecording() throws {
        // Get the input node from the audio engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Define the desired audio format (16kHz mono PCM)
        let desiredFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                        sampleRate: 16000,
                                        channels: 1,
                                        interleaved: false)!
        
        let converter = AVAudioConverter(from: format, to: desiredFormat)!
        
        // Reset the buffer before starting
        inputBuffer = []
        
        // Install a tap on the input node to capture audio data
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            // Prepare a buffer for converted audio data
            let frameCount = UInt32(buffer.frameLength)
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: desiredFormat,
                                                 frameCapacity: frameCount)!
            
            var error: NSError?
            let status = converter.convert(to: convertedBuffer,
                                        error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            // Only append frames if conversion was successful
            if status != .error, let channelData = convertedBuffer.floatChannelData?[0] {
                let frames = Array(UnsafeBufferPointer(start: channelData,
                                                     count: Int(convertedBuffer.frameLength)))
                self.inputBuffer.append(contentsOf: frames)
            }
        }
        
        // Start the audio engine
        try engine.start()
        isRecording = true
    }
    
    func stopRecording() {
        // Remove the tap and stop the engine
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }
    
    func getAudioFrames() -> [Float] {
        // Return the captured audio frames
        return inputBuffer
    }
} 