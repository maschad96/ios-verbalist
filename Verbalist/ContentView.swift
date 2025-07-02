//
//  ContentView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject private var viewModel = TaskViewModel()
    @State private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    @State private var showSettings = false
    @State private var showClearTasksConfirmation = false
    @State private var isCheckingSubscription = true
    
    // DEVELOPMENT ONLY: Set to true to force showing onboarding on next launch
    #if DEBUG
    @State private var forceShowOnboarding = false  // Changed to false to prevent forced onboarding
    #endif
    // Check if we have required API keys using the encrypted key system
    private var hasApiKey: Bool {
        let groqKey = SecureKeyManager.shared.getGroqKey()
        return !groqKey.isEmpty && groqKey != "gsk-xxxx" // Exclude debug fallback
    }
    
    var body: some View {
        ZStack {
            if !hasApiKey {
                apiKeyMissingView
            } else if isCheckingSubscription {
                // Show loading while checking subscription status
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.headline)
                        .padding(.top)
                }
                .task {
                    // Clear any force onboarding flags that might be set
                    UserDefaults.standard.set(false, forKey: "forceOnboarding")
                    UserDefaults.standard.synchronize()
                    
                    // Initialize subscription manager and check status
                    await subscriptionManager.initialize()
                    
                    // Debug: Check what the subscription status is after initialization
                    print("DEBUG ContentView: After initialization, isSubscribed = \(subscriptionManager.isSubscribed)")
                    print("DEBUG ContentView: hasCompletedOnboarding = \(hasCompletedOnboarding)")
                    print("DEBUG ContentView: UserDefaults isSubscribed = \(UserDefaults.standard.bool(forKey: "isSubscribed"))")
                    print("DEBUG ContentView: UserDefaults forceOnboarding = \(UserDefaults.standard.bool(forKey: "forceOnboarding"))")
                    
                    // Done checking, proceed to show appropriate view
                    isCheckingSubscription = false
                }
            } else {
                mainView
                    .onAppear {
                        viewModel.loadTasks()
                        
                        // Determine if we should show onboarding based on current state
                        #if DEBUG
                        if forceShowOnboarding {
                            // For development only - force show onboarding
                            hasCompletedOnboarding = false
                            showingOnboarding = true
                            forceShowOnboarding = false // Only force once per launch
                        } else {
                            // Check subscription status to determine onboarding
                            let shouldShowOnboarding = !hasCompletedOnboarding && !subscriptionManager.isSubscribed
                            print("DEBUG ContentView: shouldShowOnboarding = \(shouldShowOnboarding) (hasCompleted: \(hasCompletedOnboarding), isSubscribed: \(subscriptionManager.isSubscribed))")
                            showingOnboarding = shouldShowOnboarding
                        }
                        #else
                        // Normal production behavior
                        let shouldShowOnboarding = !hasCompletedOnboarding && !subscriptionManager.isSubscribed
                        showingOnboarding = shouldShowOnboarding
                        #endif
                    }
                    .fullScreenCover(isPresented: $showingOnboarding) {
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
                .fontWeight(.light)
                .foregroundColor(.primary)
            
            Spacer()
            
            
            // Add clear tasks button
            Button(action: {
                showClearTasksConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .padding(.trailing, 12)
            .alert("Clear All Tasks", isPresented: $showClearTasksConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    viewModel.clearAllTasks()
                }
            } message: {
                Text("Are you sure you want to delete all tasks? This action cannot be undone.")
            }
            
            // Settings button
            Button(action: {
                showSettings = true
            }) {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical)
    }
    
    private var taskListView: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if viewModel.tasks.isEmpty {
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List {
                    ForEach(viewModel.tasks) { task in
                        TaskCardView(
                            todoTask: task,
                            onToggleCompletion: { viewModel.toggleTaskCompletion(task) },
                            onDelete: { viewModel.deleteTask(task) },
                            onEdit: { viewModel.editTask(task) }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .onMove(perform: viewModel.moveTask)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .animation(.easeInOut(duration: 0.6), value: viewModel.tasks)
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
                        .foregroundColor(.sageGreen)
                    Text("Tasks added to your list!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.sageGreen.opacity(0.1))
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
