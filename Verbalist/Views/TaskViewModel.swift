//
//  TaskViewModel.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import Foundation
import SwiftUI
import Combine

enum AppState: Equatable {
    case idle
    case listening
    case transcribing
    case parsing
    case preview(task: TodoTask)
    case committed
    case error(message: String)
    
    static func == (lhs: AppState, rhs: AppState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), 
             (.listening, .listening),
             (.transcribing, .transcribing),
             (.parsing, .parsing),
             (.committed, .committed):
            return true
        case (.preview(let lhsTask), .preview(let rhsTask)):
            return lhsTask.id == rhsTask.id
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

class TaskViewModel: ObservableObject {
    @Published var tasks: [TodoTask] = []
    @Published var appState: AppState = .idle
    @Published var transcribedText: String = ""
    @Published var previewTask: TodoTask?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    private let cloudKitManager = CloudKitManager()
    let groqService = GroqService() // Public to allow settings access
    private let audioRecorder = AudioRecorder()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        subscribeToRecorder()
    }
    
    private func subscribeToRecorder() {
        audioRecorder.$isRecording
            .sink { [weak self] isRecording in
                if !isRecording && self?.appState == .listening {
                    Task { 
                        if let self = self {
                            await self.processRecording()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func startListening() {
        Task {
            let granted = await audioRecorder.requestPermission()
            
            await MainActor.run {
                if granted {
                    appState = .listening
                    audioRecorder.startRecording()
                } else {
                    appState = .error(message: "Microphone access not granted")
                }
            }
        }
    }
    
    func stopListening() {
        audioRecorder.stopRecording()
    }
    
    func cancelRecording() {
        audioRecorder.stopRecording()
        appState = .idle
    }
    
    @MainActor
    private func processRecording() async {
        guard let audioData = audioRecorder.getRecordedAudioData() else {
            appState = .error(message: "Failed to get recorded audio")
            return
        }
        
        appState = .transcribing
        
        do {
            // Transcribe the audio
            let transcription = try await groqService.transcribeAudio(audioData)
            
            transcribedText = transcription
            appState = .parsing
            
            // Parse the transcription into multiple tasks from rambling input
            let newTasks = try await groqService.parseTaskList(transcription)
            
            // Save all tasks automatically without showing modal
            await saveTasksAutomatically(newTasks)
            
        } catch {
            appState = .error(message: "Processing error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func saveTasksAutomatically(_ newTasks: [TodoTask]) async {
        guard !newTasks.isEmpty else {
            appState = .error(message: "No tasks found in your speech")
            return
        }
        
        do {
            // Save all tasks to CloudKit
            var savedTasks: [TodoTask] = []
            for task in newTasks {
                let savedTask = try await cloudKitManager.saveTask(task)
                savedTasks.append(savedTask)
            }
            
            // Add to the beginning of the tasks list
            tasks.insert(contentsOf: savedTasks, at: 0)
            
            appState = .committed
            
            // Show success message briefly, then reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.appState = .idle
            }
            
        } catch {
            appState = .error(message: "Failed to save tasks: \(error.localizedDescription)")
        }
    }
    
    func commitTask() {
        guard let task = previewTask else { return }
        
        Task {
            do {
                let savedTask = try await cloudKitManager.saveTask(task)
                 
                await MainActor.run {
                    tasks.insert(savedTask, at: 0)
                    appState = .committed
                    
                    // Reset after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.appState = .idle
                    }
                }
            } catch {
                await MainActor.run {
                    appState = .error(message: "Failed to save task: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func editTask(_ task: TodoTask) {
        previewTask = task
        appState = .preview(task: task)
    }
    
    func loadTasks() {
        isLoading = true
        
        Task {
            do {
                let fetchedTasks = try await cloudKitManager.fetchTasks()
                
                await MainActor.run {
                    tasks = fetchedTasks
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load tasks: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func toggleTaskCompletion(_ task: TodoTask) {
        var updatedTask = task
        updatedTask.isCompleted.toggle()
        
        Task {
            do {
                let savedTask = try await cloudKitManager.updateTask(updatedTask)
                
                await MainActor.run {
                    if let index = tasks.firstIndex(where: { $0.id == savedTask.id }) {
                        tasks[index] = savedTask
                    }
                }
            } catch {
                print("Error toggling completion: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        Task {
            do {
                try await cloudKitManager.deleteTask(withID: task.id)
                
                await MainActor.run {
                    tasks.removeAll { $0.id == task.id }
                }
            } catch {
                print("Error deleting task: \(error.localizedDescription)")
            }
        }
    }
    
    var audioRecorderPublisher: AudioRecorder {
        return audioRecorder
    }
}
