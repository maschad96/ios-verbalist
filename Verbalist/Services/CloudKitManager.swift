//
//  CloudKitManager.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import Foundation
import CloudKit

class CloudKitManager {
    private let container: CKContainer
    private let database: CKDatabase
    
    init() {
        self.container = CKContainer.default()
        self.database = container.privateCloudDatabase
    }
    
    func saveTasks(_ tasks: [TodoTask]) async throws -> [TodoTask] {
        var savedTasks: [TodoTask] = []
        
        for task in tasks {
            let record = task.toCKRecord()
            
            do {
                let savedRecord = try await database.save(record)
                if let savedTask = TodoTask(record: savedRecord) {
                    savedTasks.append(savedTask)
                }
            } catch {
                print("Error saving task: \(error.localizedDescription)")
                throw error
            }
        }
        
        return savedTasks
    }
    
    func saveTask(_ task: TodoTask) async throws -> TodoTask {
        let record = task.toCKRecord()
        
        do {
            let savedRecord = try await database.save(record)
            if let savedTask = TodoTask(record: savedRecord) {
                return savedTask
            } else {
                throw NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create task from saved record"])
            }
        } catch {
            print("Error saving task: \(error.localizedDescription)")
            throw error
        }
    }
    
    func fetchTasks() async throws -> [TodoTask] {
        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let result = try await database.records(matching: query)
            let records = result.matchResults.compactMap { try? $0.1.get() }
            return records.compactMap { TodoTask(record: $0) }
        } catch {
            print("Error fetching tasks: \(error.localizedDescription)")
            throw error
        }
    }
    
    func deleteTask(withID id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        
        do {
            try await database.deleteRecord(withID: recordID)
        } catch {
            print("Error deleting task: \(error.localizedDescription)")
            throw error
        }
    }
    
    func updateTask(_ task: TodoTask) async throws -> TodoTask {
        // Create a record ID from the task ID
        let recordID = CKRecord.ID(recordName: task.id.uuidString)
        
        do {
            // First fetch the existing record
            let existingRecord = try await database.record(for: recordID)
            
            // Update the existing record with new task values
            existingRecord["title"] = task.title
            existingRecord["isCompleted"] = task.isCompleted
            
            // Save the updated record
            let savedRecord = try await database.save(existingRecord)
            
            // Convert back to TodoTask
            if let savedTask = TodoTask(record: savedRecord) {
                return savedTask
            } else {
                throw NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create task from updated record"])
            }
        } catch let error as CKError where error.code == .unknownItem {
            // If record doesn't exist (which shouldn't happen), fall back to save
            print("Record not found, creating new: \(error.localizedDescription)")
            return try await saveTask(task)
        } catch {
            print("Error updating task: \(error.localizedDescription)")
            throw error
        }
    }
}
