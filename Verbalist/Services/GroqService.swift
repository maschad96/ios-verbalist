//
//  GroqService.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import Foundation
import AVFoundation
import CloudKit

class GroqService {
    private let groqBaseURL = "https://api.groq.com/openai/v1"
    private let secureKeyManager = SecureKeyManager.shared
    
    // Available models - defined as a nested type
    struct Models {
        // Groq LLM models
        static let groqLLMs = [
            "llama3-8b-8192",  // Default
            "llama3-70b-8192"
        ]
        
        // Groq supports whisper-large-v3
        static let whisperModels = [
            "whisper-large-v3"  // Default
        ]
    }
    
    // Default values
    private var currentLLMModel = "llama3-8b-8192"
    private var currentWhisperModel = "whisper-large-v3"
    
    init() {
        
        // Check for environment variable overrides
        if let modelFromEnv = ProcessInfo.processInfo.environment["GROQ_LLM_MODEL"], !modelFromEnv.isEmpty {
            self.currentLLMModel = modelFromEnv
        }
        
        if let whisperFromEnv = ProcessInfo.processInfo.environment["GROQ_WHISPER_MODEL"], !whisperFromEnv.isEmpty {
            self.currentWhisperModel = whisperFromEnv
        }
        
        // Force validate that the model is in the available models list
        if !Models.groqLLMs.contains(currentLLMModel) {
            self.currentLLMModel = Models.groqLLMs.first ?? "llama3-8b-8192"
        }
        
        // Note: API key is now handled securely via SecureKeyManager
    }
    
    // Methods to change models at runtime
    func setLLMModel(_ model: String) {
        
        if Models.groqLLMs.contains(model) {
            self.currentLLMModel = model
        } else {
            // If current model is also invalid, reset to a valid one
            if !Models.groqLLMs.contains(currentLLMModel) {
                let newModel = Models.groqLLMs.first ?? "llama3-8b-8192"
                self.currentLLMModel = newModel
            }
        }
    }
    
    func setWhisperModel(_ model: String) {
        if Models.whisperModels.contains(model) {
            self.currentWhisperModel = model
        }
    }
    
    // Get current model info
    func getCurrentModels() -> (llm: String, whisper: String) {
        return (llm: currentLLMModel, whisper: currentWhisperModel)
    }
    
    // Get available models
    func getAvailableModels() -> (llm: [String], whisper: [String]) {
        return (llm: Models.groqLLMs, whisper: Models.whisperModels)
    }
    
    // Transcribe audio using Groq's whisper-large-v3
    func transcribeAudio(_ audioData: Data) async throws -> String {
        let url = URL(string: "\(groqBaseURL)/audio/transcriptions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(secureKeyManager.getGroqKey())", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(currentWhisperModel)\r\n".data(using: .utf8)!)
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GroqService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Transcription failed"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(TranscriptionResponse.self, from: data)
        return result.text
    }
    
    // Parse task text into structured data using Groq's LLM
    func parseTask(_ text: String) async throws -> TodoTask {
        
        // Validate the model again before using it
        if !Models.groqLLMs.contains(currentLLMModel) {
            currentLLMModel = Models.groqLLMs.first ?? "llama3-8b-8192"
        }
        
        let url = URL(string: "\(groqBaseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(secureKeyManager.getGroqKey())", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        You are a task parser. Given raw spoken input, return only structured JSON for a task:
        {
        "title": "Short, actionable task title"
        }
        Only return the title field. Keep it simple and actionable. No extra commentary.
        """
        
        let requestBody: [String: Any] = [
            "model": currentLLMModel,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GroqService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Task parsing failed"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let contentString = result.choices.first?.message.content else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }
        
        // Parse JSON from the response
        return try parseTaskJSON(contentString)
    }
    
    // Parse multiple tasks from rambling speech input - perfect for morning coffee brain dumps
    func parseTaskList(_ text: String) async throws -> [TodoTask] {
        
        // Validate the model again before using it
        if !Models.groqLLMs.contains(currentLLMModel) {
            currentLLMModel = Models.groqLLMs.first ?? "llama3-8b-8192"
        }
        
        let url = URL(string: "\(groqBaseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(secureKeyManager.getGroqKey())", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        You are an expert task extraction assistant. The user will ramble about everything they need to do, and you need to extract ALL individual tasks from their speech.

        Listen for:
        - Specific actions they mention ("I need to", "I have to", "I should", "I must", "gotta", "need to remember to")
        - Appointments and meetings ("meeting with", "call", "appointment", "see the doctor")
        - Errands and shopping ("pick up", "buy", "get", "groceries", "pharmacy")
        - Work tasks and deadlines ("finish the report", "email John", "prepare presentation")
        - Personal tasks ("clean", "exercise", "walk the dog", "pay bills")

        Return a JSON array of tasks. Each task should have this structure:
        {
        "title": "Short, actionable task title"
        }

        Rules:
        - Extract EVERY actionable item, no matter how small
        - Make titles concise but clear
        - Don't miss anything - be thorough

        Return only the JSON array, no other text.
        """
        
        let requestBody: [String: Any] = [
            "model": currentLLMModel,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GroqService", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Task list parsing failed"])
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(ChatCompletionResponse.self, from: data)
        guard let contentString = result.choices.first?.message.content else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }
        
        // Parse JSON array from the response
        return try parseTaskListJSON(contentString)
    }
    
    // Helper to parse JSON task data
    private func parseTaskJSON(_ jsonString: String) throws -> TodoTask {
        let decoder = JSONDecoder()
        
        // Cleanup: sometimes the model includes markdown or extra quotes
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        
        // Try to decode into TaskJSON first
        do {
            let taskJSON = try decoder.decode(TaskJSON.self, from: jsonData)
            return TodoTask(title: taskJSON.title, isCompleted: false)
        } catch {
            // Fallback: just create a task with the raw text as title
            return TodoTask(title: jsonString, isCompleted: false)
        }
    }
    
    // Helper to parse JSON array of tasks from rambling input
    private func parseTaskListJSON(_ jsonString: String) throws -> [TodoTask] {
        let decoder = JSONDecoder()
        
        // Cleanup: sometimes the model includes markdown or extra quotes
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON string"])
        }
        
        // Try to decode into array of TaskJSON first
        do {
            let taskJSONArray = try decoder.decode([TaskJSON].self, from: jsonData)
            return taskJSONArray.map { taskJSON in
                return TodoTask(title: taskJSON.title, isCompleted: false)
            }
        } catch {
            // Fallback: try to create a single task from the entire input
            return [TodoTask(title: "Parse tasks from: \(cleanedJSON.prefix(100))...", isCompleted: false)]
        }
    }
}

// Response models
struct TranscriptionResponse: Decodable {
    let text: String
}

struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    
    let choices: [Choice]
}

// Intermediate Task JSON model
struct TaskJSON: Decodable {
    let title: String
}
