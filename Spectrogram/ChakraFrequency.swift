//
//  ChakraFrequency.swift
//  Spectrogram
//
//  Created by David Nyman on 7/6/25.
//


//
//  ChakraFrequencies.swift
//  Spectrogram
//
//  Created by Jules on 2024-07-26.
//

import Foundation
import SwiftUI // Import SwiftUI for Color

struct ChakraFrequency {
    let name: String
    let frequency: Double
    let color: Color // Optional: Add a default color for each chakra for future use
}

struct ChakraFrequencies {
    static let root = ChakraFrequency(name: "Root", frequency: 396.0, color: .red)
    static let sacral = ChakraFrequency(name: "Sacral", frequency: 417.0, color: .orange)
    static let solarPlexus = ChakraFrequency(name: "Solar Plexus", frequency: 528.0, color: .yellow)
    static let heart = ChakraFrequency(name: "Heart", frequency: 639.0, color: .green)
    static let throat = ChakraFrequency(name: "Throat", frequency: 741.0, color: .blue)
    static let thirdEye = ChakraFrequency(name: "Third Eye", frequency: 852.0, color: .indigo)
    static let crown = ChakraFrequency(name: "Crown", frequency: 963.0, color: .purple)

    static let all: [ChakraFrequency] = [
        root, sacral, solarPlexus, heart, throat, thirdEye, crown
    ]
}
