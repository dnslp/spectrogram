import SwiftUI

// This extension is similar to the one in SpectrogramSlice.
// Consider moving to a shared location if used by more components.
extension CGFloat {
    /// Maps a value from one range to another, using a logarithmic (base 10) scale for the input range.
    func mappedLog10(from fromRange: ClosedRange<CGFloat>, to toRange: ClosedRange<CGFloat>) -> CGFloat {
        guard fromRange.lowerBound > 0, fromRange.upperBound > 0 else {
            // Log of non-positive number is undefined or complex.
            // Depending on requirements, might return toRange.lowerBound, NaN, or assert.
            return toRange.lowerBound
        }
        let logLower = log10(fromRange.lowerBound)
        let logUpper = log10(fromRange.upperBound)
        let logValue = log10(self)

        // Normalize the log value to 0-1 range
        let normalized = (logValue - logLower) / (logUpper - logLower)

        // Handle cases where self might be outside fromRange after log, clamp normalized value
        let clampedNormalized = Swift.max(0, Swift.min(1, normalized))

        // Scale to the target range
        return toRange.lowerBound + clampedNormalized * (toRange.upperBound - toRange.lowerBound)
    }
}


struct FrequencyAxisView: View {
    let minFreq: CGFloat
    let maxFreq: CGFloat
    let height: CGFloat

    private let labelColor: Color = .gray
    private let labelFont: Font = .system(size: 10)
    private let minLabelSpacing: CGFloat = 20 // Minimum vertical pixels between labels

    struct LabelInfo: Identifiable, Hashable {
        let id = UUID()
        let text: String
        let yPosition: CGFloat
    }

    private var labels: [LabelInfo] {
        generateLabelInfo()
    }

    var body: some View {
        GeometryReader { geometryProxy in
            ZStack(alignment: .topTrailing) {
                ForEach(labels) { label in
                    Text(label.text)
                        .font(labelFont)
                        .foregroundColor(labelColor)
                        .position(x: geometryProxy.size.width / 2, y: label.yPosition) // Positioned within its own frame
                        .frame(width: geometryProxy.size.width, alignment: .trailing) // Ensure text is right aligned within the ZStack
                        .padding(.trailing, 4) // Padding from the very edge
                }
            }
        }
    }

    private func generateLabelInfo() -> [LabelInfo] {
        var generatedLabels: [LabelInfo] = []
        guard height > 0 && maxFreq > minFreq else { return [] }

        // 1. Generate candidate frequencies (Octaves of A, C, and some fixed Hz)
        var candidateFrequencies: [(name: String, freq: Double, isPitch: Bool)] = []

        // Add octaves of A
        let aOctaves = PitchConverter.generatePitches(minOctave: 0, maxOctave: 8, notesToInclude: ["A"])
        candidateFrequencies.append(contentsOf: aOctaves.map { ($0.name, $0.freq, true) })

        // Add octaves of C
        let cOctaves = PitchConverter.generatePitches(minOctave: 1, maxOctave: 8, notesToInclude: ["C"])
        candidateFrequencies.append(contentsOf: cOctaves.map { ($0.name, $0.freq, true) })

        // Add specific Hz values
        let fixedHz: [(name: String, freq: Double)] = [
            ("100 Hz", 100.0), ("200 Hz", 200.0), ("500 Hz", 500.0),
            ("1 kHz", 1000.0), ("2 kHz", 2000.0), ("5 kHz", 5000.0),
            ("10 kHz", 10000.0), ("15 kHz", 15000.0), ("20 kHz", 20000.0)
        ]
        candidateFrequencies.append(contentsOf: fixedHz.map { ($0.name, $0.freq, false) })

        // Sort by frequency
        candidateFrequencies.sort { $0.freq < $1.freq }

        var lastLabelY: CGFloat = -CGFloat.infinity // To track vertical spacing

        for candidate in candidateFrequencies {
            let freqCGFloat = CGFloat(candidate.freq)
            if freqCGFloat >= minFreq && freqCGFloat <= maxFreq {
                // Y position is calculated from top (0) to bottom (height)
                // Spectrogram data is often low-frequency at bottom, high at top.
                // Our slice drawing is from 0 (bottom) to sliceHeight (top).
                // So, high Y means high frequency.
                let yPos = freqCGFloat.mappedLog10(from: minFreq...maxFreq, to: 0...height)

                // Since drawing in SwiftUI usually has (0,0) at top-left,
                // and we want low frequencies at the bottom, we need to flip the yPos.
                let flippedYPos = height - yPos

                if abs(flippedYPos - lastLabelY) >= minLabelSpacing || lastLabelY == -CGFloat.infinity {
                    let labelText: String
                    if candidate.isPitch {
                        if let pitchName = PitchConverter.frequencyToPitchName(frequency: candidate.freq) {
                            labelText = "\(pitchName) (\(formatFrequency(candidate.freq, includeHzForPitch: true)))"
                        } else {
                            labelText = formatFrequency(candidate.freq) // Fallback
                        }
                    } else {
                        // For fixed Hz, candidate.name is already formatted (e.g., "1 kHz")
                        labelText = candidate.name
                    }

                    // Avoid adding label if it's too close to top or bottom edge if it's the first/only one
                    // Also ensure the label isn't empty.
                    if !labelText.isEmpty && flippedYPos > (labelFont.capHeight / 2) + 2 && flippedYPos < (height - (labelFont.capHeight / 2) - 2) {
                         generatedLabels.append(LabelInfo(text: labelText, yPosition: flippedYPos))
                         lastLabelY = flippedYPos
                    }
                }
            }
        }
        // Ensure there's always a min and max freq label if possible and not too cluttered
        // This part can be enhanced. For now, the dynamic selection handles it.

        return generatedLabels.sorted(by: { $0.yPosition < $1.yPosition }) // Sort by final Y position
    }

    private func formatFrequency(_ freq: Double, includeHzForPitch: Bool = false) -> String {
        if freq >= 10000 && !includeHzForPitch { // For 10kHz and above, just use kHz for fixed labels
            return String(format: "%.0f kHz", freq / 1000.0)
        } else if freq >= 1000 && !includeHzForPitch {
            return String(format: "%.1f kHz", freq / 1000.0)
        } else if freq >= 1000 && includeHzForPitch { // For pitches, show full Hz up to a point or simple kHz
             if freq < 10000 {
                 return String(format: "%.0f Hz", freq)
             } else {
                 return String(format: "%.1f kHz", freq / 1000.0)
             }
        } else { // Below 1000 Hz
            return String(format: "%.0f Hz", freq)
        }
    }
}

struct FrequencyAxisView_Previews: PreviewProvider {
    static var previews: some View {
        FrequencyAxisView(minFreq: 40, maxFreq: 12000, height: 300)
            .frame(width: 80, height: 300)
            .background(Color.black)
    }
}
