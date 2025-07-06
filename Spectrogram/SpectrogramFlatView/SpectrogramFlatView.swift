// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKitUI/

#if !os(macOS) || targetEnvironment(macCatalyst)

import AudioKit
import SwiftUI

/// A rolling spectrogram view with selectable color schemes and y-axis labels for pitch/frequency
public struct SpectrogramFlatView: View {
    // Default gradient
    static let defaultGradient: [UIColor] = [
        (#colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)),
        (#colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)),
        (#colorLiteral(red: 0.4217140079, green: 0.6851614118, blue: 0.9599093795, alpha: 1)),
        (#colorLiteral(red: 0.8122602105, green: 0.6033009887, blue: 0.8759307861, alpha: 1)),
        (#colorLiteral(red: 0.9826132655, green: 0.5594901443, blue: 0.4263145328, alpha: 1)),
        (#colorLiteral(red: 1, green: 0.2607713342, blue: 0.4242972136, alpha: 1))
    ]

    // Chakra-themed gradient (example)
    static let chakraGradient: [UIColor] = [
        UIColor(ChakraFrequencies.root.color.opacity(0.0)), // Transparent start
        UIColor(ChakraFrequencies.root.color),
        UIColor(ChakraFrequencies.sacral.color),
        UIColor(ChakraFrequencies.solarPlexus.color),
        UIColor(ChakraFrequencies.heart.color),
        UIColor(ChakraFrequencies.throat.color),
        UIColor(ChakraFrequencies.thirdEye.color),
        UIColor(ChakraFrequencies.crown.color),
        UIColor(ChakraFrequencies.crown.color.opacity(0.8)) // Slightly transparent end
    ]

    /// Current gradient colors in use (modified by init & picker)
    public static var gradientUIColors: [UIColor] = defaultGradient

    @StateObject var spectrogram = SpectrogramFlatModel()
    let node: Node
    @State private var selectedColorScheme: ColorScheme
    let backgroundColor: Color

    // Y-axis ticks: note labels and frequencies
    private let axisTicks: [(label: String, freq: Double)] = [
        ("C2", 65.41),
        ("C3", 130.81),
        ("C4", 261.63),
        ("C5", 523.25),
        ("C6", 1046.50),
        ("C7", 2093.00)
    ]

    /// Create a new spectrogram view
    public init(node: Node,
                initialColorScheme: ColorScheme = .standard,
                amplitudeColors: [Color] = [],
                backgroundColor: Color = Color.black) {
        self.node = node
        self.backgroundColor = backgroundColor
        self._selectedColorScheme = State(initialValue: initialColorScheme)
        
        if !amplitudeColors.isEmpty {
            if amplitudeColors.count > 1 {
                Self.gradientUIColors = amplitudeColors.map { UIColor($0) }
            } else {
                Self.gradientUIColors = [UIColor(backgroundColor), UIColor(amplitudeColors[0])]
            }
        } else {
            // Set gradient based on initial scheme
            switch initialColorScheme {
            case .standard:
                Self.gradientUIColors = SpectrogramFlatView.defaultGradient
            case .chakraBased:
                Self.gradientUIColors = SpectrogramFlatView.chakraGradient
            }
        }
    }

    /// Which color schemes are available
    public enum ColorScheme: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case chakraBased = "Chakra Colors"
        public var id: String { rawValue }
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Color scheme selector
                Picker("Color Scheme", selection: $selectedColorScheme) {
                    ForEach(ColorScheme.allCases) { scheme in
                        Text(scheme.rawValue).tag(scheme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 5)
                .onChange(of: selectedColorScheme) { newScheme in
                    switch newScheme {
                    case .standard:
                        Self.gradientUIColors = SpectrogramFlatView.defaultGradient
                    case .chakraBased:
                        Self.gradientUIColors = SpectrogramFlatView.chakraGradient
                    }
                    spectrogram.objectWillChange.send()
                }

                // Spectrogram slices + axis overlay
                ZStack {
                    backgroundColor
                        .onAppear { spectrogram.updateNode(node) }

                    HStack(spacing: 0) {
                        ForEach(spectrogram.slices.items) { slice in
                            slice
                        }
                        .scaleEffect(x: -1, y: 1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
                .overlay(
                    GeometryReader { axisGeo in
                        let height = axisGeo.size.height
                        ForEach(axisTicks, id: \.freq) { tick in
                            let freqValue = CGFloat(tick.freq)
                            let yPos = height - freqValue.mappedLog10(
                                from: spectrogram.nodeMetaData.minFreq ... spectrogram.nodeMetaData.maxFreq,
                                to: 0 ... height
                            )
                            Text("\(tick.label) \(Int(tick.freq)) Hz")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .position(x: 30, y: yPos)
                        }
                    }
                    .allowsHitTesting(false)
                )
                .onAppear {
                    spectrogram.sliceSize = calcSliceSize(fromFrameSize: geometry.size)
                }
                .onChange(of: geometry.size) { newSize in
                    spectrogram.sliceSize = calcSliceSize(fromFrameSize: newSize)
                }
            }
        }
    }

    /// Calculate how big each slice should be based on the view’s size
    func calcSliceSize(fromFrameSize frameSize: CGSize) -> CGSize {
        let availableWidth = frameSize.width
        // Each slice (including its label gutter) divides the total width evenly
        let sliceTotalWidth = floor(availableWidth / CGFloat(spectrogram.slices.maxItems))
        return CGSize(width: sliceTotalWidth, height: frameSize.height)
    }
}

// MARK: Preview

struct SpectrogramFlatView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrogramFlatView(node: Mixer())
    }
}

#endif
