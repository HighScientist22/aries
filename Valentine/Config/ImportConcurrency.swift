//
//  ImportConcurrency.swift
//  Aries
//

import Foundation

enum ImportConcurrency {
    /// Parallel metadata import — tuned for Apple Silicon core counts.
    static var limit: Int {
        let cores = ProcessInfo.processInfo.processorCount
        return min(12, max(6, cores - 2))
    }

    /// Parallel network fetches (podcast refresh, artwork).
    static var networkLimit: Int {
        min(6, max(3, ProcessInfo.processInfo.processorCount / 2))
    }
}
