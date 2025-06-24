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
    @Published var soundSamples: [Float] = []
    
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
            try recordingSession?.setCategory(.record, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
        }
        #endif
    }
    
    func requestPermission() async -> Bool {
        // Since AVAudioSession.recordPermission is deprecated in iOS 17.0,
        // we'll use AVAudioApplication.requestRecordPermission directly
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    func startRecording() {
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingURL = audioFilename
            soundSamples = []
            
            // Start monitoring audio levels with higher frequency for smoother animation
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                
                recorder.updateMeters()
                let avgPower = recorder.averagePower(forChannel: 0)
                let peakPower = recorder.peakPower(forChannel: 0)
                
                // Use a combination of average and peak for more dynamic visualization
                let combinedPower = (avgPower * 0.7) + (peakPower * 0.3)
                let normalizedPower = self.normalizeSoundLevel(level: combinedPower)
                
                // Apply some smoothing to reduce jitter
                let smoothedPower: Float
                if let lastSample = self.soundSamples.last {
                    smoothedPower = lastSample * 0.3 + normalizedPower * 0.7
                } else {
                    smoothedPower = normalizedPower
                }
                
                // Add to samples array
                self.soundSamples.append(smoothedPower)
                
                // Keep array at optimal size for circular visualization (24 samples)
                if self.soundSamples.count > 24 {
                    self.soundSamples.removeFirst()
                }
            }
            
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
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
            print("Error reading audio file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording finished unsuccessfully")
            stopRecording()
        }
    }
    
    private func normalizeSoundLevel(level: Float) -> Float {
        // Audio levels come in from -160 to 0 dB
        // Normalize to values between 0 and 1
        let minDb: Float = -80
        
        // If level is less than minDb, set it to minDb
        let adjustedLevel = max(minDb, level)
        
        // Convert to a value between 0 and 1
        return (adjustedLevel - minDb) / (0 - minDb)
    }
}
