//
//  SettingsView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isRestoringPurchases = false
    @State private var restoreMessage = ""
    @State private var showRestoreAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transcription Model")) {
                    Picker("Whisper Model", selection: $viewModel.selectedWhisperModel) {
                        ForEach(viewModel.whisperModels, id: \.self) { model in
                            Text(model)
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Language Model")) {
                    Picker("LLM Model", selection: $viewModel.selectedLLMModel) {
                        ForEach(viewModel.llmModels, id: \.self) { model in
                            Text(model)
                                .tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("API Information")) {
                    HStack {
                        Text("Groq API")
                        Spacer()
                        Text(viewModel.hasGroqKey ? "Connected" : "Not Connected")
                            .foregroundColor(viewModel.hasGroqKey ? .green : .red)
                    }
                }
                
                Section(header: Text("Subscription")) {
                    Button(action: {
                        Task {
                            await restorePurchases()
                        }
                    }) {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                            if isRestoringPurchases {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .foregroundColor(.sageGreen)
                    .disabled(isRestoringPurchases)
                }
                
                Section(header: Text("Legal")) {
                    Link("Privacy Policy", destination: URL(string: "https://www.apple.com/privacy/privacy-policy/")!)
                        .foregroundColor(.sageGreen)
                    
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/terms/site.html")!)
                        .foregroundColor(.sageGreen)
                }
                
                Section(header: Text("About")) {
                    Text("Verbalist")
                        .font(.headline)
                    Text("Version 1.0")
                        .foregroundColor(.secondary)
                    Text("A voice-driven to-do list that uses AI to convert speech to structured tasks.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Restore Purchases", isPresented: $showRestoreAlert) {
                Button("OK") { }
            } message: {
                Text(restoreMessage)
            }
            .onAppear {
                // Force refresh selected models from service
                let currentModels = viewModel.aiService.getCurrentModels()
                if viewModel.llmModels.contains(currentModels.llm) {
                    viewModel.selectedLLMModel = currentModels.llm
                }
                if viewModel.whisperModels.contains(currentModels.whisper) {
                    viewModel.selectedWhisperModel = currentModels.whisper
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func restorePurchases() async {
        isRestoringPurchases = true
        
        do {
            try await AppStore.sync()
            restoreMessage = "Purchase restore completed successfully."
        } catch {
            restoreMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isRestoringPurchases = false
        showRestoreAlert = true
    }
}

class SettingsViewModel: ObservableObject {
    @Published var selectedWhisperModel: String {
        didSet {
            aiService.setWhisperModel(selectedWhisperModel)
        }
    }
    
    @Published var selectedLLMModel: String {
        didSet {
            aiService.setLLMModel(selectedLLMModel)
        }
    }
    
    let whisperModels: [String]
    let llmModels: [String]
    let hasGroqKey: Bool
    
    let aiService: GroqService // Made public for view access
    
    init(aiService: GroqService) {
        self.aiService = aiService
        
        // Get the available models from the service
        let availableModels = aiService.getAvailableModels()
        self.whisperModels = availableModels.whisper
        self.llmModels = availableModels.llm
        
        // Get current models
        let currentModels = aiService.getCurrentModels()
        print("Current models from service - LLM: \(currentModels.llm), Whisper: \(currentModels.whisper)")
        
        // Ensure the current model is in the available models list
        if !self.llmModels.contains(currentModels.llm) {
            print("Warning: Current LLM model \(currentModels.llm) not in available models list")
            self.selectedLLMModel = self.llmModels.first ?? "llama3-8b-8192"
        } else {
            self.selectedLLMModel = currentModels.llm
        }
        
        if !self.whisperModels.contains(currentModels.whisper) {
            print("Warning: Current Whisper model \(currentModels.whisper) not in available models list")
            self.selectedWhisperModel = self.whisperModels.first ?? "whisper-large-v3"
        } else {
            self.selectedWhisperModel = currentModels.whisper
        }
        
        // Use the encrypted key system for consistent detection
        let groqKey = SecureKeyManager.shared.getGroqKey()
        self.hasGroqKey = !groqKey.isEmpty && groqKey != "gsk-xxxx"
        
        print("SettingsViewModel initialized with LLM: \(self.selectedLLMModel), Whisper: \(self.selectedWhisperModel)")
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(aiService: GroqService()))
}
