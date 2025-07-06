// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKitUI/
//

#if !os(macOS) || targetEnvironment(macCatalyst)

import AudioKit
import SwiftUI

///     Considerations for further development; depending on usage and requirements:
///     Make this struct public so the look can be configured. Define fftSize as enum.
///     Also add something like a gain or similar to adjust sensitivity of display. 
struct SpectrogramFFTMetaData {
    // fftSize defines how detailled the music is analyzed in the time domain. 
    // the lower the value, the less detail:
    // * 1024: will receive about four analyzed frequencies between C2 and C* (65Hz to 130Hz). 
    //             New data comes roughly 21.5 times per second, each 46ms.  
    // * 2048: will receive about eight analyzed frequencies between C2 and C* (65Hz to 130Hz).  
    //            New data comes roughly 11 times per second, each 93ms. 
    // * 4096: will receive about 16 analyzed frequencies between C2 and C* (65Hz to 130Hz). 
    //            New data comes roughly  5.5 times per second, each 186ms.  
    // Choose a higher value when you want to analyze low frequencies, 
    // choose a lower value when you want fast response and high frame rate on display.
    var fftSize: UInt32 // Default was 2048

    // Lowest and highest frequencies shown. 
    // We use 48Hz, which is a bit lower than G1. A1 would be 440Hz/8 = 55Hz.  
    // The lowest human bass voice in choral music is reaching down to C1 (32.7 Hz). 
    // Don't go lower than 6.0, it just doesn't make sense and the display gets terribly distorted
    // don't use 0 as it breaks the display because log10(0) is undefined and this error not handled
    var minFreq: CGFloat // Default was 48.0
    // we will not show anything above 13500 as it's not music anymore but just overtones and noise
    var maxFreq: CGFloat // Default was 13500.0

    // how/why can the sample rate be edited? Shouldn't this come from the node/engine?
    // if the sample rate is changed, does the displayed frequency range also have to be changed?
    // took this from existing SpectrogramView, will investigate later
    let sampleRate: double_t = 44100 // This could also be made dynamic if needed
}

struct SliceQueue {
    var maxItems: Int = 120 // This could also be made configurable
    var items: [SpectrogramSlice] = []

    public mutating func pushToQueue(element: SpectrogramSlice) {
        enqueue(element: element)
        if items.count > maxItems {
            dequeue()
        }
    }

    private mutating func enqueue(element: SpectrogramSlice) {
        items.append(element)
    }

    private mutating func dequeue() {
        if !items.isEmpty {
            items.remove(at: 0)
        }
    }
}

///  Model for the SpectrogramFlatView. Makes connection to the audio node and receives FFT data
class SpectrogramFlatModel: ObservableObject {
    /// A queue full of SpectrogramSlice
    @Published var slices = SliceQueue()
    /// Dimensions of the slices. Set prior to rendering to get slices that fit. 
    var sliceSize = CGSize(width: 10, height: 250) {
        didSet {
            if xcodePreview { createTestData() }
        }
    }
    var nodeMetaData: SpectrogramFFTMetaData
    var gradientUIColors: [UIColor]

    let xcodePreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    var nodeTap: FFTTap!
    var node: Node?

    // create a filled Queue, always full of stuff. looks a bit better. 
    // otherwise it would be fast moving at the beginning and then  
    // pressing together until full (looks funny though :-). 
    // In case of Xcode Preview, filling of queue will be done in 
    // setSliceSize called typically from the geometry reader. 
    init(initialFftSize: UInt32 = 2048,
         initialMinFreq: CGFloat = 48.0,
         initialMaxFreq: CGFloat = 13500.0,
         initialGradientUIColors: [UIColor] = []) {
        self.nodeMetaData = SpectrogramFFTMetaData(fftSize: initialFftSize, minFreq: initialMinFreq, maxFreq: initialMaxFreq)
        if initialGradientUIColors.isEmpty {
            // Default gradient if none provided - matches previous static variable
            self.gradientUIColors = [
                UIColor(red: 0, green: 0, blue: 0, alpha: 0),
                UIColor(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 0.6275583187),
                UIColor(red: 0.4217140079, green: 0.6851614118, blue: 0.9599093795, alpha: 0.8245213468),
                UIColor(red: 0.8122602105, green: 0.6033009887, blue: 0.8759307861, alpha: 1),
                UIColor(red: 0.9826132655, green: 0.5594901443, blue: 0.4263145328, alpha: 1),
                UIColor(red: 1, green: 0.2607713342, blue: 0.4242972136, alpha: 1)
            ]
        } else {
            self.gradientUIColors = initialGradientUIColors
        }

        if !xcodePreview {
            createEmptyData()
        }
    }

    func updateFFTParameters(newFftSize: UInt32, newMinFreq: CGFloat, newMaxFreq: CGFloat) {
        let oldFftSize = self.nodeMetaData.fftSize
        self.nodeMetaData.fftSize = newFftSize
        self.nodeMetaData.minFreq = newMinFreq
        self.nodeMetaData.maxFreq = newMaxFreq

        if newFftSize != oldFftSize, let currentNode = self.node {
            // FFTTap needs to be re-initialized if fftSize changes
            nodeTap?.stop() // Stop existing tap if any
            nodeTap = FFTTap(currentNode, bufferSize: newFftSize * 2, callbackQueue: .global()) { fftData in
                self.pushData(fftData)
            }
            nodeTap.isNormalized = false
            nodeTap.zeroPaddingFactor = 1
            nodeTap.start()
        }
        // If only minFreq/maxFreq changed, existing slices will become outdated in their mapping,
        // but new slices will use the new values.
        // For a live update of existing slices, they would need to be reprocessed or cleared.
        // Clearing the queue for simplicity when these change:
        // DispatchQueue.main.async {
        //    self.slices.items.removeAll()
        //    self.createEmptyData() // Refill with placeholders
        // }
        // Decided against clearing for now to avoid visual jump, new slices will reflect change.
    }

    func updateGradientColors(newGradientUIColors: [UIColor]) {
        self.gradientUIColors = newGradientUIColors
        // Existing slices won't update their color with this change.
        // New slices created by pushData will use the new gradient.
        // If live update of all slices is needed, would need to iterate and update them,
        // or clear and refill the queue.
    }


    // fill the queue with empty data so the layouting doesn't start in the middle
    private func createEmptyData() {
        for _ in 0 ..< slices.maxItems { // Use '<' for range
            var points: [CGPoint] = []
            for index in 0 ..< 10 {
                let frequency = CGFloat(Float(index) * Float.pi)
                let amplitude = CGFloat(-200.0)
                points.append(CGPoint(x: frequency, y: amplitude))
            }
            // size and freuqency doesnt' really matter as it will all be black
            let slice = SpectrogramSlice(
                gradientUIColors: self.gradientUIColors, // Use instance variable
                sliceWidth: sliceSize.width,
                sliceHeight: sliceSize.height,
                fftReadingsFrequencyAmplitudePairs: points,
                fftMetaData: nodeMetaData
            )
            slices.pushToQueue(element: slice)
        }
    }

    private func createTestData() {
        let testCellAmount = 200
        for _ in 0 ..< slices.maxItems { // Use '<' for range
            var points: [CGPoint] = []
            // lowest and highest frequency full amplitude to see the rendering showing full frequency spectrum
            // CGPoint x: frequency  y: Amplitude -200 ... 0 whereas 0 is full loud volume 
            for index in 0 ... testCellAmount {
                // linear frequency range from 48 to 13500 in amount of steps we generate
                let frequency = nodeMetaData.minFreq + CGFloat( index * Int((nodeMetaData.maxFreq - nodeMetaData.minFreq) / CGFloat(testCellAmount)) )
                var amplitude = CGFloat.random(in: -200 ... 0)
                // add some silence to the test data
                amplitude = amplitude < -80 ? amplitude : -200.0
                points.append(CGPoint(x: frequency, y: amplitude))
            }
            let slice = SpectrogramSlice(
                gradientUIColors: self.gradientUIColors, // Use instance variable
                sliceWidth: sliceSize.width,
                sliceHeight: sliceSize.height,
                fftReadingsFrequencyAmplitudePairs: points,
                fftMetaData: nodeMetaData
            )
            slices.pushToQueue(element: slice)
        }
    }

    func updateNode(_ node: Node) {
        // Using a background thread to get data from FFTTap. 
        // This doesn't make it more efficient but will not bother 
        // main thread and user while doing the work
        if node !== self.node || nodeTap == nil { // also initialize if nodeTap is nil (e.g. after fftSize change)
            self.node = node
            nodeTap?.stop() // Stop existing tap if any
            nodeTap = FFTTap(node, bufferSize: nodeMetaData.fftSize * 2, callbackQueue: .global()) { fftData in
                self.pushData(fftData)
            }
            // normalization would mean that on each slice, the loudest would have 
            // amplitude 1.0, independent of what has happened before. 
            // we don't want that as we want absolute measurements that can be compared over time. 
            nodeTap.isNormalized = false
            nodeTap.zeroPaddingFactor = 1
            nodeTap.start()
        }
    }

    func pushData(_ fftFloats: [Float]) {
        // Comes several times per second, depending on fftSize. 
        // This call pushes new fftReadings into the queue. 
        // Queue ist observed by the view and thus view is updated. 
        // The incoming array of floats contains 2 * fftSize entries. coded in real and imaginery part. 
        // The frequencies in the even numbers and the amplitudes in the odd numbers of the array. 
        let slice = SpectrogramSlice(
            gradientUIColors: self.gradientUIColors, // Use instance variable
            sliceWidth: sliceSize.width,
            sliceHeight: sliceSize.height,
            fftReadings: fftFloats,
            fftMetaData: nodeMetaData
        )
        // we receive the callback typically on a background thread, where 
        // also the slice image was rendered. to inform UI we dispatch it on main thread
        DispatchQueue.main.async {
            self.slices.pushToQueue(element: slice)
        }
    }

}

#endif
