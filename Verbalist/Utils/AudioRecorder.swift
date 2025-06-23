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
    private var recordingSession: AVAudioSession?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession?.setCategory(.record, mode: .default)
            try recordingSession?.setActive(true)
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
        }
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
            
            // Start monitoring audio levels
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else { return }
                
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                let normalizedPower = self.normalizeSoundLevel(level: power)
                
                // Add to samples array
                self.soundSamples.append(normalizedPower)
                
                // Keep array at reasonable size
                if self.soundSamples.count > 50 {
                    self.soundSamples.removeFirst()
                }
            }
            
            // Let user control when to stop - no auto-stop
            
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
