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

enum TaskSortOption: String, CaseIterable {
    case newest = "Newest First"
    case oldest = "Oldest First"
    case alphabetical = "A-Z"
    case completed = "Completed First"
    case incomplete = "Incomplete First"
}

class TaskViewModel: ObservableObject {
    @Published var tasks: [TodoTask] = []
    @Published var appState: AppState = .idle
    @Published var transcribedText: String = ""
    @Published var previewTask: TodoTask?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var sortOption: TaskSortOption = .newest {
        didSet {
            sortTasks()
        }
    }
    
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
            // Assign sort orders to new tasks before saving
            var tasksWithOrder = newTasks
            assignSortOrderToNewTasks(&tasksWithOrder)
            
            // Save all tasks to CloudKit
            var savedTasks: [TodoTask] = []
            for task in tasksWithOrder {
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
                // Check if this is an existing task (editing) or a new task
                let isExistingTask = tasks.contains { $0.id == task.id }
                
                let savedTask: TodoTask
                if isExistingTask {
                    // Update existing task
                    savedTask = try await cloudKitManager.updateTask(task)
                } else {
                    // Create new task
                    savedTask = try await cloudKitManager.saveTask(task)
                }
                 
                await MainActor.run {
                    if isExistingTask {
                        // Replace the existing task in the array
                        if let index = tasks.firstIndex(where: { $0.id == savedTask.id }) {
                            tasks[index] = savedTask
                        }
                    } else {
                        // Insert new task at the beginning
                        tasks.insert(savedTask, at: 0)
                    }
                    
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
                    // Debug log fetched tasks
                    print("DEBUG: Fetched \(fetchedTasks.count) tasks from CloudKit")
                    for (index, task) in fetchedTasks.enumerated() {
                        print("DEBUG: Fetched task #\(index+1): '\(task.title)' - sortOrder: \(task.sortOrder), completed: \(task.isCompleted)")
                    }
                    
                    tasks = fetchedTasks
                    
                    // Sort immediately after loading to prevent flash of unsorted content
                    sortTasks()
                    
                    // Debug log tasks after sorting
                    print("DEBUG: Tasks after sorting:")
                    for (index, task) in tasks.enumerated() {
                        print("DEBUG: Sorted task #\(index+1): '\(task.title)' - sortOrder: \(task.sortOrder), completed: \(task.isCompleted)")
                    }
                    
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
                        // Re-sort with animation after completion change to move completed items to bottom
                        withAnimation(.easeInOut(duration: 0.6)) {
                            sortTasks()
                        }
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
    
    // MARK: - Task Management
    
    func clearAllTasks() {
        // Show loading state while deleting
        isLoading = true
        
        Task {
            do {
                print("DEBUG: Starting to delete all \(tasks.count) tasks")
                
                // Get a copy of all task IDs before deletion
                let taskIDs = tasks.map { $0.id }
                
                // Delete each task from CloudKit
                for id in taskIDs {
                    do {
                        try await cloudKitManager.deleteTask(withID: id)
                        print("DEBUG: Successfully deleted task with ID: \(id)")
                    } catch {
                        print("ERROR: Failed to delete task with ID \(id): \(error.localizedDescription)")
                    }
                }
                
                // Update UI on main thread
                await MainActor.run {
                    tasks.removeAll()
                    isLoading = false
                    
                    // Show success message briefly
                    appState = .committed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.appState = .idle
                    }
                    
                    print("DEBUG: All tasks cleared from local state")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to clear tasks: \(error.localizedDescription)"
                    print("ERROR: Failed to clear all tasks: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Drag and Drop Functionality
    
    func moveTask(from sourceIndices: IndexSet, to destinationIndex: Int) {
        // Don't allow moving completed tasks above incomplete tasks
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        let completedTasks = tasks.filter { $0.isCompleted }
        
        if let sourceIndex = sourceIndices.first {
            let movingTask = tasks[sourceIndex]
            
            // If trying to move a completed task above incomplete tasks, prevent it
            if movingTask.isCompleted && destinationIndex < incompleteTasks.count {
                return
            }
            
            // If trying to move an incomplete task into completed section, prevent it
            if !movingTask.isCompleted && destinationIndex >= incompleteTasks.count {
                return
            }
            
            // Perform the move
            tasks.move(fromOffsets: sourceIndices, toOffset: destinationIndex)
            
            // Update sort orders based on new positions
            updateSortOrders()
        }
    }
    
    private func updateSortOrders() {
        // Update all local sort orders immediately for instant UI response
        var tasksToUpdate: [TodoTask] = []
        
        for (index, task) in tasks.enumerated() {
            var updatedTask = task
            let newSortOrder = tasks.count - index // Higher numbers = higher priority
            
            // Only update if sort order has changed
            if updatedTask.sortOrder != newSortOrder {
                updatedTask.sortOrder = newSortOrder
                tasks[index] = updatedTask
                tasksToUpdate.append(updatedTask)
            }
        }
        
        // Batch update to CloudKit in background if there are changes
        if !tasksToUpdate.isEmpty {
            Task {
                do {
                    let savedTasks = try await cloudKitManager.batchUpdateTasks(tasksToUpdate)
                    print("DEBUG: Batch updated \(savedTasks.count) task sort orders")
                } catch {
                    print("ERROR: Failed to batch update task sort orders: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func assignSortOrderToNewTasks(_ newTasks: inout [TodoTask]) {
        let highestSortOrder = tasks.map { $0.sortOrder }.max() ?? 0
        print("DEBUG: Assigning sort orders to new tasks - highest existing order: \(highestSortOrder)")
        
        for (index, _) in newTasks.enumerated() {
            let newSortOrder = highestSortOrder + index + 1
            print("DEBUG: Setting new task #\(index+1) sort order to \(newSortOrder)")
            newTasks[index].sortOrder = newSortOrder
        }
    }
    
    private func sortTasks() {
        // Always sort with completed items at the bottom
        tasks.sort { task1, task2 in
            // First priority: incomplete tasks come before completed tasks
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted && task2.isCompleted
            }
            
            // Second priority: apply the selected sort option within each group
            switch sortOption {
            case .newest:
                return task1.sortOrder > task2.sortOrder
            case .oldest:
                return task1.sortOrder < task2.sortOrder
            case .alphabetical:
                return task1.title.localizedCaseInsensitiveCompare(task2.title) == .orderedAscending
            case .completed:
                return task1.isCompleted && !task2.isCompleted
            case .incomplete:
                return !task1.isCompleted && task2.isCompleted
            }
        }
    }
}
