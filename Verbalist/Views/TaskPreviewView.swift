//
//  TaskPreviewView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct TaskPreviewView: View {
    @State private var task: TodoTask
    let onCommit: (TodoTask) -> Void
    let onCancel: () -> Void
    
    @State private var editedTitle: String
    
    init(task: TodoTask, onCommit: @escaping (TodoTask) -> Void, onCancel: @escaping () -> Void) {
        self._task = State(initialValue: task)
        self.onCommit = onCommit
        self.onCancel = onCancel
        self._editedTitle = State(initialValue: task.title)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Title")) {
                    TextField("Task title", text: $editedTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedTask = TodoTask(
                            id: task.id,
                            title: editedTitle.trimmingCharacters(in: .whitespaces),
                            isCompleted: task.isCompleted
                        )
                        onCommit(updatedTask)
                    }
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    TaskPreviewView(
        task: TodoTask(title: "Finish presentation"),
        onCommit: { _ in },
        onCancel: {}
    )
}
