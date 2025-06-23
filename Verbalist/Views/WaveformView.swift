//
//  WaveformView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct WaveformView: View {
    var samples: [Float]
    var color: Color
    var animating: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 3, height: max(geometry.size.height * CGFloat(sample), 3))
                        .opacity(animating ? opacityFor(index: index) : 1)
                        .animation(
                            animating ? Animation.easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.05) : .default,
                            value: animating
                        )
                }
            }
            .frame(maxHeight: .infinity)
            .frame(height: geometry.size.height)
        }
    }
    
    private func opacityFor(index: Int) -> Double {
        let normalizedIndex = Double(index) / Double(max(1, samples.count - 1))
        return 0.5 + 0.5 * sin(normalizedIndex * 2 * .pi)
    }
}

struct WaveformPlaceholder: View {
    var color: Color
    var animating: Bool
    
    var body: some View {
        let placeholderSamples: [Float] = [0.3, 0.5, 0.7, 0.5, 0.3, 0.5, 0.7, 0.5, 0.3, 0.5]
        
        WaveformView(samples: placeholderSamples, color: color, animating: animating)
            .frame(height: 40)
    }
}

#Preview {
    VStack {
        WaveformView(samples: [0.2, 0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4, 0.2, 0.4, 0.6, 0.8, 1.0, 0.8, 0.6], color: .blue, animating: true)
            .frame(height: 50)
            .padding()
        
        WaveformPlaceholder(color: .red, animating: true)
            .padding()
    }
}