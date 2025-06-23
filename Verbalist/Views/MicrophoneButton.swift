//
//  MicrophoneButton.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct MicrophoneButton: View {
    var isRecording: Bool
    var soundSamples: [Float]
    var action: () -> Void
    
    private let buttonSize: CGFloat = 72
    private let buttonColor = Color.blue
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: buttonColor.opacity(0.3), radius: 10, x: 0, y: 5)
                
                if isRecording {
                    // Animated waveform around button when recording
                    Circle()
                        .stroke(buttonColor.opacity(0.3), lineWidth: 2)
                        .frame(width: buttonSize + 20, height: buttonSize + 20)
                    
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: buttonSize + 40, height: buttonSize + 40)
                        
                        // Waveform visualization
                        WaveformView(
                            samples: soundSamples.isEmpty ? [0.5, 0.6, 0.7, 0.8, 0.7, 0.6, 0.5, 0.6, 0.7, 0.8, 0.7, 0.6, 0.5] : soundSamples,
                            color: .white,
                            animating: true
                        )
                        .frame(width: buttonSize + 30, height: 40)
                    }
                    .rotationEffect(.degrees(90))
                }
                
                // Microphone icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .frame(width: buttonSize + (isRecording ? 60 : 0), height: buttonSize + (isRecording ? 60 : 0))
        .animation(.spring(), value: isRecording)
    }
}

#Preview {
    VStack(spacing: 30) {
        MicrophoneButton(isRecording: false, soundSamples: [], action: {})
        
        MicrophoneButton(
            isRecording: true,
            soundSamples: [0.3, 0.5, 0.7, 0.8, 0.9, 0.7, 0.5, 0.3, 0.5, 0.7, 0.8, 0.9, 0.7, 0.5],
            action: {}
        )
    }
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}