import SwiftUI
import AppKit

struct ModelsView: View {
    @StateObject private var modelManager = ModelManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            List(WhisperModel.defaultModels) { model in
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.name)
                            .font(.headline)
                        Text(model.info)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if modelManager.isDownloading && modelManager.currentDownloadName == model.name {
                        VStack(spacing: 4) {
                            ProgressView(value: modelManager.downloadProgress) {
                                Text("\(Int(modelManager.downloadProgress * 100))%")
                                    .font(.caption)
                            }
                            .frame(width: 100)
                            
                            Text("Downloading...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        if model.isDownloaded {
                            Button(role: .destructive) {
                                modelManager.deleteModel(model)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Button {
                                Task {
                                    await modelManager.downloadModel(model)
                                }
                            } label: {
                                Label("Download", systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
            
            if let error = modelManager.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
        }
        .frame(width: 400, height: 300)
        .navigationTitle("Available Models")
    }
} 