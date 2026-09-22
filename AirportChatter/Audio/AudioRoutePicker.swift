#if os(iOS)
import AVKit
import SwiftUI

/// App-level route selection, separate from SoundCloud's own web controls.
struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.tintColor = UIColor(red: 0.91, green: 0.87, blue: 0.75, alpha: 0.8)
        picker.activeTintColor = UIColor(red: 0.60, green: 0.89, blue: 0.77, alpha: 1)
        picker.accessibilityLabel = "Audio output"
        return picker
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#endif
