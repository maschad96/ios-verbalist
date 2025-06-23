//
//  OnboardingView.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isShowingOnboarding: Bool
    
    var body: some View {
        TabView {
            onboardingPage(
                title: "Welcome to Verbalist",
                subtitle: "Your voice-powered to-do list",
                description: "Convert your spoken words into structured tasks with the power of AI",
                imageName: "mic.circle.fill"
            )
            
            onboardingPage(
                title: "Speak Your Tasks",
                subtitle: "No typing required",
                description: "Just tap the microphone button and speak naturally. AI will understand dates, notes, and tags",
                imageName: "waveform"
            )
            
            onboardingPage(
                title: "Smart Organization",
                subtitle: "Automatic structure",
                description: "Verbalist automatically identifies due dates, notes, and categories from your speech",
                imageName: "list.bullet.rectangle.portrait"
            )
            
            onboardingPage(
                title: "Cloud Sync",
                subtitle: "Access anywhere",
                description: "Your tasks automatically sync across all your Apple devices",
                imageName: "icloud"
            )
            
            VStack(spacing: 30) {
                Text("Ready to get started?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.blue)
                
                Text("You're all set to start using Verbalist")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    isShowingOnboarding = false
                }) {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 250, height: 50)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
    
    private func onboardingPage(title: String, subtitle: String, description: String, imageName: String) -> some View {
        VStack(spacing: 30) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Image(systemName: imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 150)
                .foregroundColor(.blue)
            
            Text(description)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    OnboardingView(isShowingOnboarding: .constant(true))
}