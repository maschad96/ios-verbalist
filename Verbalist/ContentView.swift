//
//  ContentView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @State private var showSettings = false
    // Check if we have required API keys
    private var hasApiKey: Bool {
        let hasGroq = ProcessInfo.processInfo.environment["GROQ_API_KEY"] != nil
        return hasGroq
    }
    
    var body: some View {
        ZStack {
            if !hasApiKey {
                apiKeyMissingView
            } else {
                mainView
                    .onAppear {
                        if !hasCompletedOnboarding {
                            showingOnboarding = true
                        }
                        
                        viewModel.loadTasks()
                    }
                    .sheet(isPresented: $showingOnboarding) {
                        OnboardingView(isShowingOnboarding: $showingOnboarding)
                            .onDisappear {
                                hasCompletedOnboarding = true
                            }
                    }
                    .sheet(isPresented: $showSettings) {
                        SettingsView(viewModel: SettingsViewModel(aiService: viewModel.groqService))
                    }
            }
            
            // Preview overlay
            if case .preview(let task) = viewModel.appState {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay(
                        TaskPreviewView(
                            task: task,
                            onCommit: { updatedTask in
                                viewModel.previewTask = updatedTask
                                viewModel.commitTask()
                            },
                            onCancel: {
                                viewModel.appState = .idle
                            }
                        )
                    )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: viewModel.appState)
    }
    
    private var apiKeyMissingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.slash")
                .font(.system(size: 70))
                .foregroundColor(.red)
            
            Text("API Key Missing")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Verbalist requires a Groq API key to function.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
    }
    
    private var mainView: some View {
        ZStack {
            VStack {
                statusBanner
                titleBar
                taskListView
                Spacer()
            }
            .padding()
            
            VStack {
                Spacer()
                microphoneButton
                    .padding(.bottom, 30)
            }
        }
    }
    
    private var titleBar: some View {
        HStack {
            Text("VERBALIST")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                // Toggle between completed and incomplete tasks
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical)
    }
    
    private var taskListView: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
            } else if viewModel.tasks.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.tasks) { task in
                        TaskCardView(
                            todoTask: task,
                            onToggleCompletion: { viewModel.toggleTaskCompletion(task) },
                            onDelete: { viewModel.deleteTask(task) },
                            onEdit: { viewModel.editTask(task) }
                        )
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Tasks Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Tap the microphone button below to create your first task using voice input")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
    
    private var statusBanner: some View {
        Group {
            switch viewModel.appState {
            case .idle, .preview:
                EmptyView()
                
            case .listening:
                HStack {
                    Image(systemName: "ear")
                        .foregroundColor(.blue)
                    Text("Listening...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
            case .transcribing:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                    Text("Converting speech to text...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
            case .parsing:
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                    Text("Extracting tasks from your speech...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                
            case .committed:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Tasks added to your list!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                
            case .error(let message):
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .onTapGesture {
                    viewModel.appState = .idle
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: viewModel.appState)
    }
    
    private var microphoneButton: some View {
        MicrophoneButton(
            isRecording: viewModel.appState == .listening,
            soundSamples: viewModel.audioRecorderPublisher.soundSamples,
            action: {
                if viewModel.appState == .listening {
                    viewModel.stopListening()
                } else {
                    viewModel.startListening()
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
