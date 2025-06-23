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
    
    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
    
    static func == (lhs: TodoTask, rhs: TodoTask) -> Bool {
        lhs.id == rhs.id
    }
}

// CloudKit Record conversion
extension TodoTask {
    init?(record: CKRecord) {
        guard let title = record["title"] as? String else { return nil }
        
        self.id = UUID(uuidString: record.recordID.recordName) ?? UUID()
        self.title = title
        self.isCompleted = record["isCompleted"] as? Bool ?? false
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: "Task", recordID: recordID)
        
        record["title"] = title
        record["isCompleted"] = isCompleted
        
        return record
    }
}
