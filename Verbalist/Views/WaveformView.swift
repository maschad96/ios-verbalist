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
                        .animation(.easeInOut(duration: 0.1), value: sample)
                }
            }
            .frame(maxHeight: .infinity)
            .frame(height: geometry.size.height)
        }
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
