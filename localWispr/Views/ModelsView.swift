import SwiftUI
import AppKit

struct ModelsView: View {
    @StateObject private var modelManager = ModelManager.shared
    @Environment(\.dismiss) private var dismiss
    var onModelSelect: ((Model) -> Void)?
    @State private var showAllModels = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title and close button
            HStack {
                Text(showAllModels ? "Available Models" : "Downloaded Models")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Toggle between all models and downloaded models
            Picker("Show", selection: $showAllModels) {
                Text("Downloaded").tag(false)
                Text("All Available").tag(true)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Models List
            List(showAllModels ? ModelManager.getAllModels() : modelManager.getDownloadedModels()) { model in
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(model.name)
                                .font(.headline)
                            if modelManager.isModelDownloaded(model) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
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
                        if modelManager.isModelDownloaded(model) {
                            HStack {
                                Button {
                                    onModelSelect?(model)
                                    dismiss()
                                } label: {
                                    Label("Use", systemImage: "play.circle")
                                }
                                .buttonStyle(.borderless)
                                
                                Button(role: .destructive) {
                                    modelManager.deleteModel(model)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
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
        .frame(width: 400, height: 600)
    }
} 