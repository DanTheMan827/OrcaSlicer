import SwiftUI

/// G-code viewer with layer-by-layer visualization and print path rendering.
struct GCodeView: View {
    let gcodeURL: URL?
    @StateObject private var viewModel = GCodeViewModel()
    @State private var selectedLayer: Int = 0
    @State private var showLayerSlider = true
    @State private var colorMode: ColorMode = .lineType

    enum ColorMode: String, CaseIterable, Identifiable {
        case lineType = "Line Type"
        case speed = "Speed"
        case layerHeight = "Layer Height"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // G-code path visualization
            gcodeCanvas
                .overlay(alignment: .topLeading) {
                    layerInfo
                }
                .overlay(alignment: .trailing) {
                    if showLayerSlider && viewModel.totalLayers > 0 {
                        layerSlider
                    }
                }

            // Bottom toolbar
            gcodeToolbar
        }
        .onAppear {
            if let url = gcodeURL {
                viewModel.loadGCode(from: url)
            }
        }
    }

    private var gcodeCanvas: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard !viewModel.layers.isEmpty,
                      selectedLayer < viewModel.layers.count else {
                    // Draw empty bed
                    drawBuildPlate(context: context, size: size)
                    return
                }

                drawBuildPlate(context: context, size: size)
                drawLayer(viewModel.layers[selectedLayer], context: context, size: size)
            }
            .background(Color(.systemBackground))
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        viewModel.zoomLevel = max(0.5, min(5.0, scale))
                    }
            )
        }
    }

    private var layerInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.totalLayers > 0 {
                Text("Layer \(selectedLayer + 1) / \(viewModel.totalLayers)")
                    .font(.caption.monospacedDigit())
                Text("Z: \(viewModel.layerHeight(at: selectedLayer), specifier: "%.2f") mm")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text("Loading G-code...")
                    .font(.caption)
            } else {
                Text("No G-code loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding()
    }

    private var layerSlider: some View {
        VStack {
            Slider(
                value: Binding(
                    get: { Double(selectedLayer) },
                    set: { selectedLayer = Int($0) }
                ),
                in: 0...Double(max(0, viewModel.totalLayers - 1)),
                step: 1
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 40, height: 200)
        }
        .padding(.trailing, 8)
    }

    private var gcodeToolbar: some View {
        HStack {
            // Color mode picker
            Picker("Color", selection: $colorMode) {
                ForEach(ColorMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            Spacer()

            // Layer navigation buttons
            HStack(spacing: 16) {
                Button {
                    selectedLayer = max(0, selectedLayer - 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(selectedLayer <= 0)

                Button {
                    selectedLayer = min(viewModel.totalLayers - 1, selectedLayer + 1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(selectedLayer >= viewModel.totalLayers - 1)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Drawing

    private func drawBuildPlate(context: GraphicsContext, size: CGSize) {
        let plateSize = min(size.width, size.height) * 0.8
        let origin = CGPoint(
            x: (size.width - plateSize) / 2,
            y: (size.height - plateSize) / 2
        )
        let rect = CGRect(origin: origin, size: CGSize(width: plateSize, height: plateSize))

        // Plate background
        context.fill(
            Path(roundedRect: rect, cornerRadius: 4),
            with: .color(Color(.systemGray6))
        )

        // Grid lines
        let gridSpacing: CGFloat = plateSize / 10
        var gridPath = Path()
        for i in 0...10 {
            let x = origin.x + CGFloat(i) * gridSpacing
            gridPath.move(to: CGPoint(x: x, y: origin.y))
            gridPath.addLine(to: CGPoint(x: x, y: origin.y + plateSize))

            let y = origin.y + CGFloat(i) * gridSpacing
            gridPath.move(to: CGPoint(x: origin.x, y: y))
            gridPath.addLine(to: CGPoint(x: origin.x + plateSize, y: y))
        }
        context.stroke(gridPath, with: .color(Color(.systemGray4)), lineWidth: 0.5)
    }

    private func drawLayer(_ layer: GCodeLayer, context: GraphicsContext, size: CGSize) {
        let plateSize = min(size.width, size.height) * 0.8
        let origin = CGPoint(
            x: (size.width - plateSize) / 2,
            y: (size.height - plateSize) / 2
        )

        // Scale factor: assume 220mm bed maps to plateSize
        let scale = plateSize / 220.0

        for segment in layer.segments {
            var path = Path()
            let startX = origin.x + segment.start.x * scale
            let startY = origin.y + plateSize - segment.start.y * scale
            let endX = origin.x + segment.end.x * scale
            let endY = origin.y + plateSize - segment.end.y * scale

            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            let color = colorForSegment(segment)
            context.stroke(path, with: .color(color), lineWidth: max(1, segment.width * scale * 0.5))
        }
    }

    private func colorForSegment(_ segment: GCodeSegment) -> Color {
        switch colorMode {
        case .lineType:
            switch segment.type {
            case .outerWall: return .orange
            case .innerWall: return .yellow
            case .infill: return .green
            case .support: return .cyan
            case .travel: return .gray.opacity(0.3)
            case .topSurface: return .red
            case .bottomSurface: return .purple
            }
        case .speed:
            let normalized = min(1.0, segment.speed / 200.0)
            return Color(hue: (1.0 - normalized) * 0.7, saturation: 0.8, brightness: 0.9)
        case .layerHeight:
            let normalized = min(1.0, segment.layerHeight / 0.4)
            return Color(hue: normalized * 0.3, saturation: 0.7, brightness: 0.9)
        }
    }
}

// MARK: - View Model

@MainActor
final class GCodeViewModel: ObservableObject {
    @Published var layers: [GCodeLayer] = []
    @Published var totalLayers: Int = 0
    @Published var isLoading: Bool = false
    @Published var zoomLevel: Double = 1.0

    private var layerHeights: [Double] = []

    func loadGCode(from url: URL) {
        isLoading = true
        Task {
            let parsed = await parseGCode(url: url)
            self.layers = parsed.layers
            self.totalLayers = parsed.layers.count
            self.layerHeights = parsed.heights
            self.isLoading = false
        }
    }

    func layerHeight(at index: Int) -> Double {
        guard index < layerHeights.count else { return 0 }
        return layerHeights[index]
    }

    private func parseGCode(url: URL) async -> (layers: [GCodeLayer], heights: [Double]) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ([], [])
        }

        var layers: [GCodeLayer] = []
        var heights: [Double] = []
        var currentSegments: [GCodeSegment] = []
        var currentZ: Double = 0
        var currentX: Double = 0
        var currentY: Double = 0
        var currentE: Double = 0
        var currentSpeed: Double = 60
        var currentType: GCodeSegment.SegmentType = .outerWall

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect layer change comments
            if trimmed.hasPrefix(";LAYER_CHANGE") || trimmed.hasPrefix("; layer") {
                if !currentSegments.isEmpty {
                    layers.append(GCodeLayer(z: currentZ, segments: currentSegments))
                    heights.append(currentZ)
                    currentSegments = []
                }
                continue
            }

            // Detect line type comments
            if trimmed.hasPrefix(";TYPE:") {
                let typeStr = String(trimmed.dropFirst(6))
                currentType = parseSegmentType(typeStr)
                continue
            }

            // Parse G0/G1 moves
            guard trimmed.hasPrefix("G0 ") || trimmed.hasPrefix("G1 ") else { continue }

            var newX = currentX
            var newY = currentY
            var newZ = currentZ
            var newE = currentE
            var newSpeed = currentSpeed

            let parts = trimmed.split(separator: " ")
            for part in parts {
                let value = String(part.dropFirst())
                switch part.first {
                case "X": newX = Double(value) ?? currentX
                case "Y": newY = Double(value) ?? currentY
                case "Z": newZ = Double(value) ?? currentZ
                case "E": newE = Double(value) ?? currentE
                case "F": newSpeed = (Double(value) ?? currentSpeed) / 60.0 // mm/min to mm/s
                default: break
                }
            }

            // Z change means new layer
            if newZ != currentZ && !currentSegments.isEmpty {
                layers.append(GCodeLayer(z: currentZ, segments: currentSegments))
                heights.append(currentZ)
                currentSegments = []
            }

            // Only draw segments with extrusion (E movement)
            let isExtrusion = newE > currentE
            let isTravel = !isExtrusion && (newX != currentX || newY != currentY)

            if isExtrusion || isTravel {
                let segment = GCodeSegment(
                    start: CGPoint(x: currentX, y: currentY),
                    end: CGPoint(x: newX, y: newY),
                    type: isTravel ? .travel : currentType,
                    speed: newSpeed,
                    width: 0.4,
                    layerHeight: newZ - currentZ > 0 ? newZ - currentZ : 0.2
                )
                currentSegments.append(segment)
            }

            currentX = newX
            currentY = newY
            currentZ = newZ
            currentE = newE
            currentSpeed = newSpeed
        }

        // Final layer
        if !currentSegments.isEmpty {
            layers.append(GCodeLayer(z: currentZ, segments: currentSegments))
            heights.append(currentZ)
        }

        return (layers, heights)
    }

    private func parseSegmentType(_ typeStr: String) -> GCodeSegment.SegmentType {
        let lower = typeStr.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.contains("outer") || lower.contains("external") { return .outerWall }
        if lower.contains("inner") || lower.contains("internal") { return .innerWall }
        if lower.contains("infill") || lower.contains("fill") { return .infill }
        if lower.contains("support") { return .support }
        if lower.contains("top") { return .topSurface }
        if lower.contains("bottom") { return .bottomSurface }
        return .outerWall
    }
}

// MARK: - Data Models

struct GCodeLayer {
    let z: Double
    let segments: [GCodeSegment]
}

struct GCodeSegment {
    let start: CGPoint
    let end: CGPoint
    let type: SegmentType
    let speed: Double
    let width: Double
    let layerHeight: Double

    enum SegmentType {
        case outerWall
        case innerWall
        case infill
        case support
        case travel
        case topSurface
        case bottomSurface
    }
}

#Preview {
    GCodeView(gcodeURL: nil)
}
