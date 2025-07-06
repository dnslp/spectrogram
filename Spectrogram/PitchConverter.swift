import Foundation

struct PitchConverter {

    static let noteNamesWithSharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let noteNamesWithFlats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    /// Converts a frequency in Hz to a musical pitch string (e.g., "A4", "C#5").
    ///
    /// - Parameters:
    ///   - frequency: The frequency in Hertz.
    ///   - useSharps: If true, uses sharp notation (e.g., C#), otherwise uses flat notation (e.g., Db).
    /// - Returns: A string representing the musical pitch, or nil if the frequency is out of a typical range or invalid.
    static func frequencyToPitchName(frequency: Double, useSharps: Bool = true) -> String? {
        guard frequency > 0 else { return nil }

        // Calculate MIDI note number from frequency
        // MIDI note number for A4 (440 Hz) is 69
        let midiNoteNumber = 69.0 + 12.0 * log2(frequency / 440.0)

        // Round to the nearest integer MIDI note number
        let roundedMidiNote = Int(round(midiNoteNumber))

        // Ensure it's within a reasonable MIDI range (0-127)
        guard (0...127).contains(roundedMidiNote) else { return nil }

        let noteIndex = roundedMidiNote % 12
        let octave = (roundedMidiNote / 12) - 1 // MIDI octave convention adjustment

        let noteName: String
        if useSharps {
            noteName = noteNamesWithSharps[noteIndex]
        } else {
            noteName = noteNamesWithFlats[noteIndex]
        }

        return "\(noteName)\(octave)"
    }

    /// Calculates the frequency of a given musical pitch.
    /// Based on A4 = 440 Hz.
    /// - Parameter pitch: A tuple containing the note name (e.g., "A", "C#") and the octave (e.g., 4).
    /// - Returns: The frequency in Hertz, or nil if the pitch name is invalid.
    static func pitchToFrequency(noteName: String, octave: Int) -> Double? {
        let notes = noteNamesWithSharps // Using sharps as the base for indexing
        guard let noteIndex = notes.firstIndex(of: noteName.uppercased()) ?? noteNamesWithFlats.firstIndex(of: noteName.uppercased()) else {
            // Attempt to find in flats if not in sharps, or if input was flat
            if let flatIndex = noteNamesWithFlats.firstIndex(of: noteName.uppercased()) {
                 guard let sharpEquivalentIndex = notes.firstIndex(of: noteNamesWithSharps[flatIndex]) else { return nil }
                 return calculateFrequency(noteIndex: sharpEquivalentIndex, octave: octave)
            }
            return nil
        }
        return calculateFrequency(noteIndex: noteIndex, octave: octave)
    }

    private static func calculateFrequency(noteIndex: Int, octave: Int) -> Double {
         // MIDI note number calculation: C4 is 60. A4 is 69.
         // Our noteIndex is 0-11 (C to B).
         // Octave for C starts at note 0.
         // midiNote = (octave + 1) * 12 + noteIndex
        let midiNoteNumber = Double((octave + 1) * 12 + noteIndex)
        return 440.0 * pow(2.0, (midiNoteNumber - 69.0) / 12.0)
    }

    /// Generates a list of frequencies for notes within a specified octave range.
    ///
    /// - Parameters:
    ///   - minOctave: The minimum octave (e.g., 0 for A0).
    ///   - maxOctave: The maximum octave (e.g., 8 for C8).
    ///   - notesToInclude: An array of note names (e.g., ["A", "C"]) to include. If empty, all notes are included.
    /// - Returns: An array of tuples, each containing the pitch name (String) and its frequency (Double).
    static func generatePitches(minOctave: Int = 0, maxOctave: Int = 8, notesToInclude: [String] = []) -> [(name: String, freq: Double)] {
        var pitches: [(name: String, freq: Double)] = []
        let notes = noteNamesWithSharps

        for octave in minOctave...maxOctave {
            for (index, noteBaseName) in notes.enumerated() {
                if !notesToInclude.isEmpty && !notesToInclude.contains(where: { $0.caseInsensitiveCompare(noteBaseName) == .orderedSame }) {
                    continue
                }

                let pitchName = "\(noteBaseName)\(octave)"
                if let frequency = pitchToFrequency(noteName: noteBaseName, octave: octave) {
                    // Basic validation to avoid extremely low/high frequencies if logic is flawed
                    if frequency > 0 && frequency < 20000 { // Typical human hearing upper limit
                         pitches.append((name: pitchName, freq: frequency))
                    }
                }
            }
        }
        return pitches
    }
}
