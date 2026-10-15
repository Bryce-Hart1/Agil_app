import SwiftUI

// CLAUDE  Date 10/14/2026 last changed: 10/15/2026 by: CLAUDE
// The picture on the plate calculator: a flat, code-drawn bar (or machine sleeve) with this
// load's plates drawn onto it, all in one outline-and-fill style so nothing looks more detailed
// than the rest. (10/15) Replaces the straight_bar / ez_bar PNGs, which read as uncanny next to
// flat plates. The PNGs are still in the asset catalog but nothing uses them now.
struct PlateStage: View {
    let mode: PlateCalculatorMode
    let bar: BarChoice
    /// The plates on ONE sleeve; a barbell's other sleeve mirrors it.
    let load: PlateLoad
    let sides: Int
    let surface: Color

    /// Stage height as a fraction of its width; tall enough for a 45 lb plate.
    static let heightRatio: CGFloat = 0.36
    private let ink: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                if mode == .barbell {
                    barbell(width: width)
                } else {
                    machine(width: width)
                }
            }
            .frame(width: width, height: width * Self.heightRatio, alignment: .topLeading)
            .clipped()
        }
        .aspectRatio(1 / Self.heightRatio, contentMode: .fit)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: load)
        .animation(.easeInOut(duration: 0.25), value: bar)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Barbell

    // Everything is a fraction of the stage width. The shaft goes down first so its ends tuck
    // under the collars; each side is then drawn once and mirrored. Plates stack outward from
    // the collar's outer face toward the sleeve end.
    @ViewBuilder
    private func barbell(width: CGFloat) -> some View {
        let mid = width * Self.heightRatio / 2
        let shaftHeight = width * 0.04
        let sleeveHeight = width * 0.072
        let collarWidth = width * 0.026
        let collarHeight = width * 0.12
        let collarCenter = width * 0.19
        let sleeveEnd = width * 0.015
        let collarFace = collarCenter - collarWidth / 2

        if bar == .ez {
            ezShaft(width: width, mid: mid, thickness: shaftHeight)
        } else {
            part(cornerRadius: shaftHeight * 0.4)
                .frame(width: width - 2 * collarCenter, height: shaftHeight)
                .position(x: width / 2, y: mid)
        }

        ForEach([false, true], id: \.self) { mirrored in
            let flip: (CGFloat) -> CGFloat = { mirrored ? width - $0 : $0 }
            part(cornerRadius: sleeveHeight * 0.3)
                .frame(width: collarCenter - sleeveEnd, height: sleeveHeight)
                .position(x: flip((sleeveEnd + collarCenter) / 2), y: mid)
            part(cornerRadius: 3)
                .frame(width: collarWidth, height: collarHeight)
                .position(x: flip(collarCenter), y: mid)
            plateStack(from: flip(collarFace), direction: mirrored ? 1 : -1,
                       room: collarFace - sleeveEnd, mid: mid, width: width)
        }
    }

    // A W-shaped tube: flat at each collar, down to the two hand positions, up to a flat middle.
    // Straight runs joined by rounded corners; the arc radius sets how sharp a bend reads. The
    // outline is a wider ink stroke under a surface-colored one, so the tube stays hollow-looking.
    private func ezShaft(width: CGFloat, mid: CGFloat, thickness: CGFloat) -> some View {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: width * x, y: mid + width * y)
        }
        let points = [point(0.19, 0), point(0.27, 0), point(0.335, 0.052), point(0.455, -0.012),
                      point(0.545, -0.012), point(0.665, 0.052), point(0.73, 0), point(0.81, 0)]
        let path = Path { path in
            path.move(to: points[0])
            for index in 1..<(points.count - 1) {
                path.addArc(tangent1End: points[index], tangent2End: points[index + 1],
                            radius: width * 0.03)
            }
            path.addLine(to: points[points.count - 1])
        }
        return ZStack {
            path.stroke(Color.primary, style: StrokeStyle(lineWidth: thickness + ink * 2,
                                                          lineJoin: .round))
            path.stroke(surface, style: StrokeStyle(lineWidth: thickness, lineJoin: .round))
        }
    }

    // MARK: - Machine

    // One sleeve standing off a stop flange on a stub of machine frame. Plates stack outward
    // from the flange exactly like a barbell sleeve; the caption says how many sleeves count.
    @ViewBuilder
    private func machine(width: CGFloat) -> some View {
        let mid = width * Self.heightRatio / 2
        let sleeveHeight = width * 0.064
        let armStart = width * 0.06
        let flangeX = width * 0.30
        let flangeWidth = width * 0.026
        let sleeveEnd = width * 0.92

        part(cornerRadius: 4)
            .frame(width: flangeX - armStart, height: sleeveHeight * 1.5)
            .position(x: (armStart + flangeX) / 2, y: mid)
        part(cornerRadius: sleeveHeight * 0.3)
            .frame(width: sleeveEnd - flangeX, height: sleeveHeight)
            .position(x: (flangeX + sleeveEnd) / 2, y: mid)
        part(cornerRadius: 3)
            .frame(width: flangeWidth, height: width * 0.15)
            .position(x: flangeX, y: mid)

        plateStack(from: flangeX + flangeWidth / 2, direction: 1,
                   room: sleeveEnd - flangeX - flangeWidth, mid: mid, width: width)

        Text(sides == 1 ? "One side" : "Both sides")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .position(x: width * 0.15, y: mid + width * 0.11)
    }

    private func part(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary, lineWidth: ink))
    }

    // MARK: - Plates

    // One sleeve's plates, heaviest against the collar. When the stack is longer than the
    // sleeve every plate thins by the same factor, so a heavy load still fits on the art.
    private func plateStack(from collarX: CGFloat, direction: CGFloat, room: CGFloat,
                            mid: CGFloat, width: CGFloat) -> some View {
        let placed = placedPlates(room: room, width: width)
        return ForEach(placed) { plate in
            PlateShape(surface: surface)
                .frame(width: plate.thickness, height: plate.height)
                .position(x: collarX + direction * (plate.offset + plate.thickness / 2), y: mid)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
        }
    }

    private struct PlacedPlate: Identifiable {
        let id: String
        let offset: CGFloat
        let thickness: CGFloat
        let height: CGFloat
    }

    // Identity is "<plate>-<nth of that plate>", so adding a 45 slides the lighter plates
    // outward instead of re-skinning every plate in place.
    private func placedPlates(room: CGFloat, width: CGFloat) -> [PlacedPlate] {
        var seen: [Double: Int] = [:]
        let stack = load.stack
        let natural = stack.reduce(CGFloat(0)) { $0 + Self.thickness(of: $1) * width }
        let squeeze = natural > room && natural > 0 ? room / natural : 1
        var offset: CGFloat = 0
        return stack.map { plate in
            let nth = seen[plate, default: 0]
            seen[plate] = nth + 1
            let thickness = Self.thickness(of: plate) * width * squeeze
            defer { offset += thickness }
            return PlacedPlate(id: "\(plate)-\(nth)", offset: offset,
                               thickness: thickness, height: Self.height(of: plate) * width)
        }
    }

    // Plate proportions as fractions of the stage width; heavier plates are taller and thicker.
    private static func height(of plate: Double) -> CGFloat {
        switch plate {
        case 45...: return 0.30
        case 35...: return 0.26
        case 25...: return 0.22
        case 10...: return 0.17
        case 5...:  return 0.14
        default:    return 0.11
        }
    }

    private static func thickness(of plate: Double) -> CGFloat {
        switch plate {
        case 45...: return 0.026
        case 35...: return 0.024
        case 25...: return 0.022
        case 10...: return 0.017
        case 5...:  return 0.014
        default:    return 0.012
        }
    }

    private var accessibilityText: String {
        let stack = load.stack
        guard !stack.isEmpty else {
            return mode == .barbell ? "Empty bar" : "No plates loaded"
        }
        let list = stack.map { SetFormat.weight($0) }.joined(separator: ", ")
        if mode == .machine && sides == 1 { return "Plates on the sleeve: \(list)" }
        return "Plates on each side: \(list)"
    }
}

// CLAUDE  Date 10/14/2026
// One plate seen edge-on: an outlined slab with an inset rim line, in the same ink as the bar.
private struct PlateShape: View {
    let surface: Color

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width * 0.35, 6)
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(surface)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.45), lineWidth: 1)
                    .padding(.horizontal, geo.size.width * 0.28)
                    .padding(.vertical, geo.size.height * 0.08)
            }
        }
    }
}
