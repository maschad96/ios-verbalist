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
    private let expandedSize: CGFloat = 140
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    // Outer pulsing ring
                    Circle()
                        .stroke(buttonColor.opacity(0.2), lineWidth: 2)
                        .frame(width: expandedSize, height: expandedSize)
                        .scaleEffect(isRecording ? 1.1 : 1.0)
                        .opacity(isRecording ? 0.8 : 0.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isRecording)
                    
                    // Background for waveform
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: expandedSize - 20, height: expandedSize - 20)
                }
                
                // Main button circle
                Circle()
                    .fill(buttonColor)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(color: buttonColor.opacity(0.3), radius: isRecording ? 15 : 8, x: 0, y: isRecording ? 8 : 4)
                
                if isRecording {
                    // Circular waveform around the button
                    CircularWaveformView(
                        samples: soundSamples.isEmpty ? generatePlaceholderSamples() : Array(soundSamples.suffix(24)),
                        radius: 50,
                        color: .white.opacity(0.8),
                        animating: isRecording
                    )
                }
                
                // Microphone icon
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
                    .scaleEffect(isRecording ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isRecording)
            }
        }
        .frame(width: expandedSize, height: expandedSize)
        .animation(.easeInOut(duration: 0.4), value: isRecording)
    }
    
    private func generatePlaceholderSamples() -> [Float] {
        // Generate more natural looking placeholder samples
        return (0..<24).map { i in
            let base = 0.3 + 0.4 * sin(Double(i) * 0.5) * sin(Double(i) * 0.1)
            let noise = Float.random(in: -0.1...0.1)
            return max(0.1, min(0.9, Float(base) + noise))
        }
    }
}

// New circular waveform view for better visual appeal
struct CircularWaveformView: View {
    var samples: [Float]
    var radius: CGFloat
    var color: Color
    var animating: Bool
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let angleStep = 2 * .pi / Double(samples.count)
            
            for (index, sample) in samples.enumerated() {
                let angle = Double(index) * angleStep - .pi / 2
                
                // Make the waveform much more responsive to audio
                let normalizedSample = max(0.05, min(1.0, sample))
                let barHeight = CGFloat(normalizedSample) * 25 + 2
                
                let innerPoint = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                
                let outerPoint = CGPoint(
                    x: center.x + cos(angle) * (radius + barHeight),
                    y: center.y + sin(angle) * (radius + barHeight)
                )
                
                // Create gradient effect based on sample intensity
                let intensity = CGFloat(normalizedSample)
                let opacity = 0.4 + (intensity * 0.6)
                
                context.stroke(
                    Path { path in
                        path.move(to: innerPoint)
                        path.addLine(to: outerPoint)
                    },
                    with: .color(color.opacity(opacity)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                
                // Add inner glow effect for high intensity samples
                if intensity > 0.7 {
                    context.stroke(
                        Path { path in
                            path.move(to: innerPoint)
                            path.addLine(to: outerPoint)
                        },
                        with: .color(color.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                }
            }
        }
        .frame(width: (radius + 30) * 2, height: (radius + 30) * 2)
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
    .background(Color.gray.opacity(0.1))
}
