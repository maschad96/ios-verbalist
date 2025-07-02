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
            throw error
        }
    }
    
    func fetchTasks() async throws -> [TodoTask] {
        
        do {
            // Use CKQueryOperation for more control
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            
            let operation = CKQueryOperation(query: query)
            operation.zoneID = nil
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            var records: [CKRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    // Handle individual record fetch error
                }
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(_):
                        // Convert records to tasks
                        var tasks: [TodoTask] = []
                        for record in records {
                            if let task = TodoTask(record: record) {
                                tasks.append(task)
                            }
                        }
                        
                        // Sort by sortOrder (higher values come first)
                        let sortedTasks = tasks.sorted { task1, task2 in
                            // Sort by sortOrder, if equal then sort by ID for stability
                            if task1.sortOrder != task2.sortOrder {
                                return task1.sortOrder > task2.sortOrder
                            } else {
                                return task1.id.uuidString > task2.id.uuidString
                            }
                        }
                        
                        continuation.resume(returning: sortedTasks)
                        
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                database.add(operation)
            }
            
        } catch {
            throw error
        }
    }
    
    func deleteTask(withID id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        
        do {
            try await database.deleteRecord(withID: recordID)
        } catch {
            throw error
        }
    }
    
    func updateTask(_ task: TodoTask) async throws -> TodoTask {
        
        do {
            // Create record for update
            let recordToUpdate = task.toCKRecord()
            
            // Use modify to properly handle CloudKit record updates
            let (savedRecords, _) = try await database.modifyRecords(
                saving: [recordToUpdate],
                deleting: [],
                savePolicy: .changedKeys,  // Only update fields that have changed
                atomically: true
            )
            
            // Process the result - modifyRecords returns a dictionary of recordID to Result
            guard let firstResult = savedRecords.first?.value else {
                throw NSError(domain: "CloudKitManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get updated record from modify operation"
                ])
            }
            
            // Extract the actual record from the Result
            let record: CKRecord
            switch firstResult {
            case .success(let savedRecord):
                record = savedRecord
            case .failure(let error):
                throw error
            }
            
            // Convert back to TodoTask
            if let savedTask = TodoTask(record: record) {
                return savedTask
            } else {
                throw NSError(domain: "CloudKitManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create task from updated record"
                ])
            }
        } catch let error as CKError {
            if error.code == .unknownItem {
                // If record doesn't exist, try to create it
                return try await saveTask(task)
            }
            
            throw error
        } catch {
            throw error
        }
    }
    
    // Method to update multiple tasks at once (for sort order updates)
    func batchUpdateTasks(_ tasks: [TodoTask]) async throws -> [TodoTask] {
        do {
            
            // Get all records to update
            let recordsToUpdate = tasks.map { task -> CKRecord in
                return task.toCKRecord()
            }
            
            // Use modifyRecords to update multiple records at once
            let (savedRecords, _) = try await database.modifyRecords(
                saving: recordsToUpdate,
                deleting: [],
                savePolicy: .changedKeys,  // Only update fields that have changed
                atomically: false  // Don't require all to succeed
            )
            
            
            // Convert saved records back to tasks
            var updatedTasks: [TodoTask] = []
            
            // Process the results - modifyRecords returns a dictionary of recordID to Result
            for (_, result) in savedRecords {
                switch result {
                case .success(let record):
                    if let task = TodoTask(record: record) {
                        updatedTasks.append(task)
                    }
                    
                case .failure(_):
                    // Handle individual record update error
                    break
                }
            }
            
            return updatedTasks
            
        } catch {
            throw error
        }
    }
}
