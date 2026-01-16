import SwiftUI

struct AutoSlideshowTimeoutPicker: View {
    @Binding var timeout: Int
    let options: [Int] = [0, 1, 3, 5, 10, 15, 30, 60] // 0 = Off
    
    var body: some View {
        Picker(String(localized: "Auto-Start After"), selection: $timeout) {
            ForEach(options, id: \.self) { value in
                if value == 0 {
                    Text(String(localized: "Off")).tag(0)
                } else {
                    Text("\(value) \(String(localized: "min"))").tag(value)
                }
            }
        }
        .pickerStyle(.menu)
        .frame(width: 170, alignment: .trailing)
    }
}


#Preview {
    @Previewable
    @State var timeout = 10
    return AutoSlideshowTimeoutPicker(timeout: $timeout)
}
