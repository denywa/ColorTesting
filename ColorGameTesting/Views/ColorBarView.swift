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
        return GeometryReader { geometry in
            HStack(spacing: 0) {
                if colors.isEmpty {
                    Rectangle()
                        .fill(.gray.opacity(0.35))
                        .frame(width: geometry.size.width)
                } else {
                    ForEach(colors, id: \.id) { color in
                        Rectangle()
                            .fill(Color(.sRGB, red: color.sRGB.x,
                                        green: color.sRGB.y, blue: color.sRGB.z,
                                        opacity: 1))
                            .frame(width: geometry.size.width * (ratios[color.id] ?? 0))
                    }
                }
            }
            .frame(height: geometry.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color mix")
        .accessibilityValue(colors.isEmpty ? "Empty" : colors.map { color in
            "\(color.name), \(Int(((ratios[color.id] ?? 0) * 100).rounded())) percent"
        }.joined(separator: ", "))
    }
}
