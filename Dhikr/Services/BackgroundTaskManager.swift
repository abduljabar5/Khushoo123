//
//  BackgroundTaskManager.swift
//  Dhikr
//
//  Created by Performance Optimization
//

import Foundation

actor BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var taskQueue: [String: Task<Void, Never>] = [:]
    
    private init() {}
    
    // MARK: - Task Management
    func scheduleTask<T>(
        id: String,
        priority: TaskPriority = .utility,
        operation: @escaping () async throws -> T,
        completion: @MainActor @escaping (Result<T, Error>) -> Void
    ) {
        // Cancel existing task with same ID
        taskQueue[id]?.cancel()
        
        // Create new task
        let task = Task(priority: priority) {
            do {
                let result = try await operation()
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
        
        taskQueue[id] = task
    }
    
    func cancelTask(id: String) {
        taskQueue[id]?.cancel()
        taskQueue.removeValue(forKey: id)
    }
    
    func cancelAllTasks() {
        for task in taskQueue.values {
            task.cancel()
        }
        taskQueue.removeAll()
    }
    
    // MARK: - Specialized Operations
    func processDataInBackground<T>(
        id: String,
        data: [T],
        batchSize: Int = 100,
        processor: @escaping (ArraySlice<T>) -> Void,
        completion: @MainActor @escaping () -> Void
    ) {
        scheduleTask(id: id, priority: .utility) {
            // Process data in batches to avoid blocking
            for batch in data.chunked(into: batchSize) {
                processor(batch)
                
                // Yield control periodically
                await Task.yield()
            }
        } completion: { result in
            switch result {
            case .success:
                completion()
            case .failure(let error):
                completion()
            }
        }
    }
    
    func debounce(
        id: String,
        delay: TimeInterval,
        operation: @escaping () async -> Void
    ) {
        // Cancel existing debounced task
        taskQueue[id]?.cancel()
        
        // Create new debounced task
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            if !Task.isCancelled {
                await operation()
            }
        }
        
        taskQueue[id] = task
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [ArraySlice<Element>] {
        return stride(from: 0, to: count, by: size).map {
            self[$0..<Swift.min($0 + size, count)]
        }
    }
} 