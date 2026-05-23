import SwiftUI

/// Model transformation controls for positioning, scaling, and rotating models on the bed.
struct ModelTransformView: View {
    @Binding var transform: ModelTransform
    @State private var activeTab: TransformTab = .move

    enum TransformTab: String, CaseIterable {
        case move = "Move"
        case rotate = "Rotate"
        case scale = "Scale"

        var icon: String {
            switch self {
            case .move: return "arrow.up.and.down.and.arrow.left.and.right"
            case .rotate: return "rotate.3d"
            case .scale: return "arrow.up.left.and.arrow.down.right"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Tab selector
            Picker("Transform", selection: $activeTab) {
                ForEach(TransformTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)

            // Controls for selected tab
            switch activeTab {
            case .move:
                moveControls
            case .rotate:
                rotateControls
            case .scale:
                scaleControls
            }

            // Reset button
            HStack {
                Spacer()
                Button("Reset") {
                    withAnimation {
                        transform = .identity
                    }
                }
                .font(.caption)
                .tint(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var moveControls: some View {
        VStack(spacing: 8) {
            axisControl(label: "X", value: $transform.positionX, range: -200...200, unit: "mm")
            axisControl(label: "Y", value: $transform.positionY, range: -200...200, unit: "mm")
            axisControl(label: "Z", value: $transform.positionZ, range: 0...500, unit: "mm")
        }
    }

    private var rotateControls: some View {
        VStack(spacing: 8) {
            axisControl(label: "X", value: $transform.rotationX, range: 0...360, unit: "°")
            axisControl(label: "Y", value: $transform.rotationY, range: 0...360, unit: "°")
            axisControl(label: "Z", value: $transform.rotationZ, range: 0...360, unit: "°")
        }
    }

    private var scaleControls: some View {
        VStack(spacing: 8) {
            Toggle("Uniform Scale", isOn: $transform.uniformScale)
                .font(.caption)
                .onChange(of: transform.uniformScale) { _, isUniform in
                    if isUniform {
                        transform.scaleY = transform.scaleX
                        transform.scaleZ = transform.scaleX
                    }
                }

            if transform.uniformScale {
                axisControl(label: "All", value: $transform.scaleX, range: 1...500, unit: "%")
                    .onChange(of: transform.scaleX) { _, newValue in
                        transform.scaleY = newValue
                        transform.scaleZ = newValue
                    }
            } else {
                axisControl(label: "X", value: $transform.scaleX, range: 1...500, unit: "%")
                axisControl(label: "Y", value: $transform.scaleY, range: 1...500, unit: "%")
                axisControl(label: "Z", value: $transform.scaleZ, range: 1...500, unit: "%")
            }
        }
    }

    private func axisControl(label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.bold())
                .frame(width: 24, alignment: .leading)
                .foregroundStyle(.secondary)

            Slider(value: value, in: range)

            Text("\(value.wrappedValue, specifier: "%.1f")\(unit)")
                .font(.caption.monospacedDigit())
                .frame(width: 60, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }
}

/// Model transformation data.
struct ModelTransform: Equatable {
    var positionX: Double = 0
    var positionY: Double = 0
    var positionZ: Double = 0
    var rotationX: Double = 0
    var rotationY: Double = 0
    var rotationZ: Double = 0
    var scaleX: Double = 100
    var scaleY: Double = 100
    var scaleZ: Double = 100
    var uniformScale: Bool = true

    static var identity: ModelTransform {
        ModelTransform()
    }
}

#Preview {
    ModelTransformView(transform: .constant(.identity))
        .padding()
}
