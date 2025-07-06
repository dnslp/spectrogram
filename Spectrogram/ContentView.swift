//
//  ContentView.swift
//  Spectrogram
//
//  Created by David Nyman on 7/6/25.
//

import SwiftUI
import AudioKit
import AVFoundation

/// A simple wrapper that conforms to ObservableObject
/// and manages the AudioKit engine + mic → mixer routing.
class SpectrogramConductor: ObservableObject, HasAudioEngine {
    let engine = AudioEngine()
    let mixer  = Mixer()

    init() {
        // 1. Configure AVAudioSession
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("AudioSession setup error:", error)
        }

        // 2. Route mic into mixer
        if let mic = engine.input {
            mixer.addInput(mic)
        }

        // 3. Make mixer the engine output
        engine.output = mixer

        // 4. Start the engine
        do {
            try engine.start()
        } catch {
            print("Audio engine failed to start:", error)
        }
    }
}

struct ContentView: View {
    // Now this is a proper ObservableObject
    @StateObject private var conductor = SpectrogramConductor()

    var body: some View {
        SpectrogramFlatView(node: conductor.mixer,
                            initialFftSize: 2048,      // Default FFT size
                            initialMinFreq: 48.0,      // Default Min Frequency
                            initialMaxFreq: 13500.0,   // Default Max Frequency
                            amplitudeColors: [],       // Use default gradient, or specify an array of Colors
                            backgroundColor: .black)   // Default background color
            .padding()
            // No need to reconfigure onAppear; the init already did it.
    }
}


#Preview {
    ContentView()
}
