//
//  AudioRecorder.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import Foundation
import AVFoundation
import SwiftUI

class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingURL: URL?
    // Start with zeros for proper animation from bottom
    @Published var soundSamples: [Float] = Array(repeating: 0.0, count: 20)
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    #if os(iOS)
    private var recordingSession: AVAudioSession?
    #endif
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        #if os(iOS)
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession?.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try recordingSession?.setActive(true)
        } catch {
        }
        #endif
    }
    
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            #if os(iOS)
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: true)
            case .denied:
                continuation.resume(returning: false)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            @unknown default:
                continuation.resume(returning: false)
            }
            #else
            // For macOS
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
            #endif
        }
    }
    
    func startRecording() {
        
        // Set up audio session specifically for recording
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
        } catch {
            return
        }
        #endif
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(UUID().uuidString).wav")
        
        // Use Linear PCM in WAV format for better metering accuracy
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            
            guard let recorder = audioRecorder else {
                return
            }
            
            let started = recorder.record()
            
            if started {
                isRecording = true
                recordingURL = audioFilename
                // Reset to zeros when starting recording to ensure animation from bottom
                soundSamples = Array(repeating: 0.0, count: 20)
                
                // Start monitoring audio levels with higher frequency for smoother animation
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                    guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                    
                    recorder.updateMeters()
                    let avgPower = recorder.averagePower(forChannel: 0)
                    let peakPower = recorder.peakPower(forChannel: 0)
                    
                    
                    // Generate multiple samples for a more interesting visualization
                    var newSamples = [Float]()
                    
                    // Main amplitude from peak power
                    let normalizedPeak = self.normalizeSoundLevel(level: peakPower)
                    
                    // Create a varied pattern based on the current audio level
                    for i in 0..<20 {
                        // Base value from actual audio
                        let baseSample = normalizedPeak
                        
                        // Add some variation
                        let variation = Float(sin(Double(i) * 0.3 + Date().timeIntervalSince1970 * 2.0)) * 0.15
                        
                        // Apply weighted average with previous sample (if exists) for smoothing
                        let prevSample: Float
                        if self.soundSamples.isEmpty {
                            prevSample = 0.0
                        } else {
                            let prevIndex = i % self.soundSamples.count
                            prevSample = self.soundSamples[prevIndex]
                        }
                        
                        // Weight for smoothing (less smoothing = more responsive)
                        let weight: Float = 0.3
                        let smoothedSample = prevSample * weight + (baseSample + variation) * (1.0 - weight)
                        
                        // Ensure we stay in valid range and have minimum activity
                        let finalSample = max(0.15, min(1.0, smoothedSample))
                        newSamples.append(finalSample)
                    }
                    
                    // Add to samples array on main thread
                    DispatchQueue.main.async {
                        // Completely replace samples with new ones
                        self.soundSamples = newSamples
                    }
                }
            }
            
        } catch {
            stopRecording()
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    func getRecordedAudioData() -> Data? {
        guard let url = recordingURL else { return nil }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            stopRecording()
        }
    }
    
    private func normalizeSoundLevel(level: Float) -> Float {
        // Audio levels come in from -160 to 0 dB
        // Use a more sensitive range for voice input
        let minDb: Float = -60  // Even more sensitive to quieter sounds
        let maxDb: Float = -10  // Cap at reasonable speaking volume
        
        // Clamp the level to our desired range
        let clampedLevel = max(minDb, min(maxDb, level))
        
        // Convert to a value between 0 and 1
        let normalized = (clampedLevel - minDb) / (maxDb - minDb)
        
        // Apply a stronger curve to make it more responsive to voice
        // The 0.5 power makes even quieter inputs produce visible activity
        let curved = pow(normalized, 0.5) 
        
        // Boost the values slightly to ensure good visualization
        let boosted = curved * 1.2
        
        // Make sure we stay in valid range
        return max(0.1, min(1.0, boosted))
    }
}
