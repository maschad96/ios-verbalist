//
//  TodoTask.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import Foundation
import CloudKit

struct TodoTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
    
    static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        lhs.id == rhs.id
    }
}

// CloudKit Record conversion
extension TodoTask {
    init?(record: CKRecord) {
        // Initialize all properties first
        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.isCompleted = record["isCompleted"] as? Bool ?? false
        self.sortOrder = record["sortOrder"] as? Int ?? 0
        
        // Then check required fields
        guard let title = record["title"] as? String else { return nil }
        self.title = title
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Task", recordID: recordID)
        
        record["title"] = title
        record["isCompleted"] = isCompleted
        record["sortOrder"] = sortOrder
        
        return record
    }
}
