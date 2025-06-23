//
//  TaskCardView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct TaskCardView: View {
    let todoTask: TodoTask
    let onToggleCompletion: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggleCompletion) {
                Image(systemName: todoTask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todoTask.isCompleted ? .green : .gray)
                    .font(.title2)
            }
            
            Text(todoTask.title)
                .font(.headline)
                .strikethrough(todoTask.isCompleted)
                .foregroundColor(todoTask.isCompleted ? .gray : .primary)
            
            Spacer()
            
            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .padding(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(action: onToggleCompletion) {
                Label(todoTask.isCompleted ? "Mark Incomplete" : "Mark Complete", 
                      systemImage: todoTask.isCompleted ? "circle" : "checkmark.circle")
            }
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    VStack {
        TaskCardView(
            todoTask: TodoTask(title: "Buy groceries"),
            onToggleCompletion: {},
            onDelete: {},
            onEdit: {}
        )
        
        TaskCardView(
            todoTask: TodoTask(title: "Finish project", isCompleted: true),
            onToggleCompletion: {},
            onDelete: {},
            onEdit: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
