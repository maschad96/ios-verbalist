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
    
    private let buttonSize: CGFloat = 80
    private let buttonColor = Color.blue
    
    // Animated properties
    @State private var glowOpacity: Double = 0
    @State private var scale: CGFloat = 1.0
    
    // State to track when we've just started recording
    @State private var isTransitioning: Bool = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording || isTransitioning {
                    // Animated equalizer background
                    EqualizerView(
                        // Always use real samples if available, otherwise animate
                        samples: soundSamples.isEmpty ? generateAnimatedSamples() : soundSamples,
                        isAnimating: isRecording
                    )
                    .frame(width: 160, height: 160)
                    
                    // Stop button in the center
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.red.opacity(0.5), radius: 5, x: 0, y: 0)
                        .scaleEffect(scale)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                .scaleEffect(scale + 0.2)
                                .opacity(glowOpacity)
                        )
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                glowOpacity = 0.7
                                scale = 1.1
                            }
                        }
                } else {
                    // Static microphone button
                    Circle()
                        .fill(buttonColor)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: buttonColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .frame(width: 160, height: 160)
        .onChange(of: isRecording) { oldValue, newValue in
            // Handle transition state for smoother animations
            if newValue {
                // We're starting to record - set transition state
                isTransitioning = true
                
                // After a short delay, clear the transition state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTransitioning = false
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isRecording)
    }
    
    // Start with all zeros to ensure animation from bottom
    private func generateZeroSamples() -> [Float] {
        return Array(repeating: 0.01, count: 20)
    }
    
    // Generate smooth animated wave samples
    private func generateAnimatedSamples() -> [Float] {
        let time = Date().timeIntervalSince1970
        return (0..<20).map { i in
            let frequency1 = 1.5 + Double(i) * 0.1
            let frequency2 = 2.0 + Double(i) * 0.05
            let wave1 = sin(time * frequency1)
            let wave2 = sin(time * frequency2)
            let combined = (wave1 + wave2) / 2.0
            let amplitude = 0.3 + abs(combined) * 0.6
            return Float(max(0.2, min(1.0, amplitude)))
        }
    }
}

// New music equalizer-style view
struct EqualizerView: View {
    var samples: [Float]
    var isAnimating: Bool
    
    private let barCount = 20
    private let barSpacing: CGFloat = 2
    
    var body: some View {
        HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let sample = index < samples.count ? samples[index] : 0.0
                
                EqualizerBar(
                    sample: sample,
                    isAnimating: isAnimating,
                    index: index
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

struct EqualizerBar: View {
    let sample: Float
    let isAnimating: Bool
    let index: Int
    
    @State private var animatedHeight: CGFloat = 0
    @State private var animationTimer: Timer?
    
    private let maxBarHeight: CGFloat = 25
    private let minBarHeight: CGFloat = 3
    
    var body: some View {
        VStack(spacing: 1) {
            // Top half extending upward
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: animatedHeight)
            
            // Bottom half extending downward  
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: animatedHeight)
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startContinuousAnimation()
            } else {
                stopAnimation()
            }
        }
        .onAppear {
            if isAnimating {
                startContinuousAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startContinuousAnimation() {
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let time = Date().timeIntervalSince1970
            let frequency = 1.5 + Double(index) * 0.2
            let wave = sin(time * frequency)
            let height = minBarHeight + CGFloat(abs(wave)) * maxBarHeight
            
            withAnimation(.easeInOut(duration: 0.1)) {
                animatedHeight = height
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        withAnimation(.easeOut(duration: 0.3)) {
            animatedHeight = 0
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        MicrophoneButton(isRecording: false, soundSamples: [], action: {})
        
        MicrophoneButton(
            isRecording: true,
            soundSamples: [0.3, 0.5, 0.7, 0.8, 0.9, 0.7, 0.5, 0.3, 0.5, 0.7, 0.8, 0.9, 0.7, 0.5, 0.6, 0.4, 0.8, 0.3, 0.9, 0.2],
            action: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
