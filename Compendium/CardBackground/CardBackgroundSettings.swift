import SwiftUI

struct CardBackgroundSettings: View {
    @Binding var background: CardBackground
    @State private var showingImagePicker = false
    
    var body: some View {
        List {
            Section("Style") {
                Picker("Background Style", selection: $background.style) {
                    Text("None").tag(CardBackgroundStyle.none)
                    Text("Grid").tag(CardBackgroundStyle.grid)
                    Text("Lined").tag(CardBackgroundStyle.lined)
                    Text("Image").tag(CardBackgroundStyle.image)
                }
            }
            if background.style == .image {
                Section("Image") {
                    Button(background.imageData == nil ? "Select Image" : "Change Image") {
                        showingImagePicker = true
                    }
                    
                    if background.imageData != nil {
                        VStack(alignment: .leading) {
                            Text("Opacity: \(Int(background.imageOpacity * 100))%")
                            Slider(
                                value: $background.imageOpacity,
                                in: 0.0...1.0,
                                step: 0.01
                            )
                        }
                        .padding(.vertical, 4)
                        
                        Button("Remove Image", role: .destructive) {
                            background.imageData = nil
                            background.originalImageSize = nil
                            background.style = .none
                        }
                    }
                }
            } else if background.style != .none {
                Section("Line Settings") {
                    ColorPicker("Line Color", selection: $background.lineColor)
                    
                    VStack(alignment: .leading) {
                        Text("Line Width: \(background.lineWidth, specifier: "%.1f")")
                        Slider(value: $background.lineWidth, in: 0.5...5)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Line Spacing: \(background.spacing, specifier: "%.0f")")
                        Slider(value: $background.spacing, in: 10...50)
                    }
                }
                
                Section("Margins") {
                    MarginSettings(
                        title: "Left Margin",
                        margin: $background.margins.left,
                        suffix: "% of width"
                    )
                    
                    MarginSettings(
                        title: "Right Margin",
                        margin: $background.margins.right,
                        suffix: "% of width"
                    )
                    
                    MarginSettings(
                        title: "Top Margin",
                        margin: $background.margins.top,
                        suffix: "% of height"
                    )
                    
                    MarginSettings(
                        title: "Bottom Margin",
                        margin: $background.margins.bottom,
                        suffix: "% of height"
                    )
                }
            }
        }
        .navigationTitle("Background Settings")
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(imageData: $background.imageData, originalSize: $background.originalImageSize)
        }
    }
}

struct MarginSettings: View {
    let title: String
    @Binding var margin: CardMargins.Margin
    let suffix: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(title, isOn: $margin.isEnabled)
            
            if margin.isEnabled {
                VStack(alignment: .leading) {
                    Text("\(Int(margin.percentage))\(suffix)")
                    Slider(value: $margin.percentage, in: 5...45)
                }
                .padding(.leading)
            }
        }
    }
}

