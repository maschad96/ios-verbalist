//
//  SettingsView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SettingsViewModel
    
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
                    
                    
                    Text("To change API keys, update the environment variables in your Xcode scheme.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        
        self.hasGroqKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] != nil
        
        print("SettingsViewModel initialized with LLM: \(self.selectedLLMModel), Whisper: \(self.selectedWhisperModel)")
    }
}

#Preview {
    SettingsView(viewModel: SettingsViewModel(aiService: GroqService()))
}