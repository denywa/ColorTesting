import SwiftUI

struct ColorBarView: View {
    let mix: Mix

    private var orderedColors: [NamedColor] {
        var seen = Set<UUID>()
        return mix.units.compactMap { unit in
            seen.insert(unit.color.id).inserted ? unit.color : nil
        }
    }

    var body: some View {
        let colors = orderedColors
        let ratios = mix.ratios
        
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            
            if colors.isEmpty {
                var path = Path()
                path.addArc(center: center, radius: radius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                context.fill(path, with: .color(.gray.opacity(0.35)))
            } else {
                var currentAngle = Angle.degrees(-90)
                for color in colors {
                    let ratio = ratios[color.id] ?? 0
                    let sweepAngle = Angle.degrees(ratio * 360)
                    let endAngle = currentAngle + sweepAngle
                    
                    var path = Path()
                    path.move(to: center)
                    path.addArc(center: center, radius: radius, startAngle: currentAngle, endAngle: endAngle, clockwise: false)
                    path.closeSubpath()
                    
                    let uiColor = Color(.sRGB, red: color.sRGB.x, green: color.sRGB.y, blue: color.sRGB.z, opacity: 1)
                    context.fill(path, with: .color(uiColor))
                    
                    currentAngle = endAngle
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color mix pie chart")
        .accessibilityValue(colors.isEmpty ? "Empty" : colors.map { color in
            "\(color.name), \(Int(((ratios[color.id] ?? 0) * 100).rounded())) percent"
        }.joined(separator: ", "))
    }
}
