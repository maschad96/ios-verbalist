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
        print("DEBUG: Starting CloudKit fetch with ultra-basic query...")
        
        do {
            // Use CKQueryOperation for more control
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            
            print("DEBUG: Creating query operation...")
            let operation = CKQueryOperation(query: query)
            operation.zoneID = nil
            operation.resultsLimit = CKQueryOperation.maximumResults
            
            var records: [CKRecord] = []
            
            operation.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("DEBUG: Error fetching individual record: \(error)")
                }
            }
            
            return try await withCheckedThrowingContinuation { continuation in
                operation.queryResultBlock = { result in
                    switch result {
                    case .success(_):
                        print("DEBUG: CloudKit operation completed successfully with \(records.count) records")
                        
                        // Convert records to tasks
                        var tasks: [TodoTask] = []
                        for (index, record) in records.enumerated() {
                            print("DEBUG: Processing record \(index + 1)")
                            print("DEBUG: Record fields: \(record.allKeys())")
                            
                            if let task = TodoTask(record: record) {
                                tasks.append(task)
                                print("DEBUG: ✅ Successfully converted record to task: '\(task.title)'")
                            } else {
                                print("DEBUG: ❌ Failed to convert record to TodoTask")
                                print("DEBUG: Record title field: \(record["title"] ?? "nil")")
                                print("DEBUG: Record isCompleted field: \(record["isCompleted"] ?? "nil")")
                            }
                        }
                        
                        print("DEBUG: Final result: Successfully converted \(tasks.count) out of \(records.count) records")
                        
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
                        print("DEBUG: CloudKit operation failed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                
                database.add(operation)
            }
            
        } catch {
            print("DEBUG: CloudKit fetch failed with error: \(error)")
            if let ckError = error as? CKError {
                print("DEBUG: CloudKit error code: \(ckError.code.rawValue)")
                print("DEBUG: CloudKit error description: \(ckError.localizedDescription)")
            }
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
        print("DEBUG: Starting update for task '\(task.title)' (ID: \(task.id), sortOrder: \(task.sortOrder))")
        
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
                print("DEBUG: Successfully saved task with record ID: \(record.recordID.recordName)")
                print("DEBUG: Updated record fields: \(record.allKeys().map { "\($0): \(String(describing: record[$0]))" }.joined(separator: ", "))")
            case .failure(let error):
                throw error
            }
            
            // Convert back to TodoTask
            if let savedTask = TodoTask(record: record) {
                print("DEBUG: Successfully converted record to task: '\(savedTask.title)' with sortOrder: \(savedTask.sortOrder)")
                return savedTask
            } else {
                throw NSError(domain: "CloudKitManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to create task from updated record"
                ])
            }
        } catch let error as CKError {
            print("ERROR: CloudKit error updating task: \(error.localizedDescription) (code: \(error.code.rawValue))")
            
            if error.code == .unknownItem {
                // If record doesn't exist, try to create it
                print("DEBUG: Record not found, attempting to create new record")
                return try await saveTask(task)
            }
            
            throw error
        } catch {
            print("ERROR: Unknown error updating task: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Method to update multiple tasks at once (for sort order updates)
    func batchUpdateTasks(_ tasks: [TodoTask]) async throws -> [TodoTask] {
        do {
            print("DEBUG: Starting batch update for \(tasks.count) tasks")
            
            // Log task details before update
            for (index, task) in tasks.enumerated() {
                print("DEBUG: Task #\(index+1) to update: ID=\(task.id), title='\(task.title)', sortOrder=\(task.sortOrder)")
            }
            
            // Get all records to update
            let recordsToUpdate = tasks.map { task -> CKRecord in
                let record = task.toCKRecord()
                print("DEBUG: Created record for update: ID=\(record.recordID.recordName), sortOrder=\(record["sortOrder"] ?? "nil")")
                return record
            }
            
            // Use modifyRecords to update multiple records at once
            print("DEBUG: Sending \(recordsToUpdate.count) records to CloudKit for batch update...")
            let (savedRecords, _) = try await database.modifyRecords(
                saving: recordsToUpdate,
                deleting: [],
                savePolicy: .changedKeys,  // Only update fields that have changed
                atomically: false  // Don't require all to succeed
            )
            
            print("DEBUG: CloudKit returned \(savedRecords.count) updated records")
            
            // Convert saved records back to tasks
            var updatedTasks: [TodoTask] = []
            
            // Process the results - modifyRecords returns a dictionary of recordID to Result
            for (recordID, result) in savedRecords {
                print("DEBUG: Processing result for record ID: \(recordID.recordName)")
                
                switch result {
                case .success(let record):
                    print("DEBUG: Successfully updated record: \(record.recordID.recordName)")
                    if let task = TodoTask(record: record) {
                        updatedTasks.append(task)
                        print("DEBUG: ✅ Successfully updated task '\(task.title)' with sortOrder: \(task.sortOrder)")
                    } else {
                        print("DEBUG: ❌ Failed to convert record to task: \(record.recordID.recordName)")
                    }
                    
                case .failure(let recordError):
                    print("DEBUG: Error updating record \(recordID.recordName): \(recordError.localizedDescription)")
                }
            }
            
            print("DEBUG: Batch update completed - updated \(updatedTasks.count) of \(tasks.count) tasks")
            return updatedTasks
            
        } catch let error as CKError {
            print("ERROR: CloudKit error in batch update: \(error.localizedDescription) (code: \(error.code.rawValue))")
            
            // Check if there are per-record errors
            if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                print("DEBUG: Partial errors detected on \(partialErrors.count) records:")
                for (recordID, recordError) in partialErrors {
                    print("DEBUG: Error on record \(recordID.recordName): \(recordError.localizedDescription)")
                }
            }
            
            throw error
        } catch {
            print("ERROR: Failed to batch update task sort orders: \(error.localizedDescription)")
            throw error
        }
    }
}
