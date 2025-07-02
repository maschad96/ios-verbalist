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
            Image(systemName: todoTask.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(todoTask.isCompleted ? .sageGreen : .gray)
                .font(.title2)
                .onTapGesture {
                    onToggleCompletion()
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5)
        .contentShape(Rectangle())
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
