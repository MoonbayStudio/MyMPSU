import SwiftUI

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let base = CGRect(x: rect.minX + w * 0.10, y: rect.minY + h * 0.38, width: w * 0.80, height: h * 0.48)
        let left = CGRect(x: rect.minX + w * 0.12, y: rect.minY + h * 0.24, width: w * 0.28, height: h * 0.44)
        let mid = CGRect(x: rect.minX + w * 0.34, y: rect.minY + h * 0.10, width: w * 0.33, height: h * 0.48)
        let right = CGRect(x: rect.minX + w * 0.58, y: rect.minY + h * 0.22, width: w * 0.26, height: h * 0.42)

        var path = Path()
        path.addRoundedRect(in: base, cornerSize: CGSize(width: h * 0.22, height: h * 0.22))
        path.addEllipse(in: left)
        path.addEllipse(in: mid)
        path.addEllipse(in: right)
        return path
    }
}

struct DynamicThemeShape: Shape {
    let themedShape: ThemedComponentShape

    func path(in rect: CGRect) -> Path {
        switch themedShape {
        case .capsule:
            return RoundedRectangle(cornerRadius: 16, style: .continuous).path(in: rect)
        case .roundedCard:
            return RoundedRectangle(cornerRadius: 16, style: .continuous).path(in: rect)
        case .cloud:
            return CloudShape().path(in: rect)
        }
    }
}

struct ThemedChrome<Content: View>: View {
    let shape: ThemedComponentShape
    let showsBackground: Bool
    @ViewBuilder let content: Content
    @AppStorage("selectedThemeID") private var selectedThemeID = AppThemeCatalog.default
    @Environment(\.mympsuSurfaceStrokeOpacity) private var strokeOpacity

    init(shape: ThemedComponentShape, showsBackground: Bool = true, @ViewBuilder content: () -> Content) {
        self.shape = shape
        self.showsBackground = showsBackground
        self.content = content()
    }

    var body: some View {
        switch shape {
        case .capsule:
            content
                .background(capsuleBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(capsuleStroke)
        case .roundedCard:
            content
                .background(roundedCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(roundedCardStroke)
        case .cloud:
            content
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    CloudShape()
                        .fill(cloudSurfaceFill)
                        .offset(y: -6)
                )
                .overlay(
                    CloudShape()
                        .stroke(cloudSurfaceStroke, lineWidth: 0.9)
                        .offset(y: -6)
                )
                .shadow(color: cloudHighlightShadow, radius: 4, x: 0, y: -1)
                .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 7)
        }
    }

    private var activeTheme: AppTheme {
        AppThemeCatalog.theme(for: selectedThemeID)
    }

    private var cloudSurfaceFill: Color {
        activeTheme.cloudSurfaceFill
    }

    private var cloudSurfaceStroke: Color {
        activeTheme.cloudSurfaceStroke
    }

    private var cloudHighlightShadow: Color {
        activeTheme.backgroundStyle == .dreamySkyNight
        ? Color.white.opacity(0.04)
        : Color.white.opacity(0.20)
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        if showsBackground {
            Color.mympsuHeaderCapsuleFill
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var capsuleStroke: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.mympsuSurfaceStrokeBase.opacity(showsBackground ? strokeOpacity : 0.18), lineWidth: 0.8)
    }

    @ViewBuilder
    private var roundedCardStroke: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.mympsuSurfaceStrokeBase.opacity(showsBackground ? strokeOpacity : 0.18), lineWidth: 0.8)
    }

    @ViewBuilder
    private var roundedCardBackground: some View {
        if !showsBackground {
            Color.clear
        } else {
#if os(iOS)
            if #available(iOS 15.0, *) {
                Color.clear.background(.ultraThinMaterial)
            } else {
                Color.white.opacity(0.10)
            }
#elseif os(macOS)
            if #available(macOS 12.0, *) {
                Color.clear.background(.ultraThinMaterial)
            } else {
                Color(NSColor.windowBackgroundColor).opacity(0.88)
            }
#else
            Color.white.opacity(0.10)
#endif
        }
    }
}

struct ThemedBackground: View {
    let theme: AppTheme

    var body: some View {
        switch theme.backgroundStyle {
        case .system:
#if os(iOS)
            Color(uiColor: .systemBackground)
#elseif os(macOS)
            Color(NSColor.windowBackgroundColor)
#else
            Color.clear
#endif
        case .dreamySkyDay:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.70, green: 0.86, blue: 1.00),
                        Color(red: 0.83, green: 0.92, blue: 1.00),
                        Color(red: 0.94, green: 0.96, blue: 1.00)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if theme.usesCloudPattern {
                    dayCloudPattern
                }
            }
        case .dreamySkyNight:
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.18),
                        Color(red: 0.09, green: 0.13, blue: 0.28),
                        Color(red: 0.14, green: 0.17, blue: 0.34)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                starPattern

                if theme.usesCloudPattern {
                    nightCloudPattern
                }
            }
        case .tokyoCityDay:
            themedGradient(
                colors: [
                    Color(red: 0.91, green: 0.96, blue: 1.00),
                    Color(red: 0.74, green: 0.86, blue: 0.98),
                    Color(red: 1.00, green: 0.86, blue: 0.94)
                ],
                hasNeonGrid: true,
                gridColor: Color(red: 0.08, green: 0.62, blue: 1.00).opacity(0.12)
            )
        case .tokyoCityNight:
            themedGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.09),
                    Color(red: 0.08, green: 0.07, blue: 0.20),
                    Color(red: 0.21, green: 0.04, blue: 0.20)
                ],
                hasNeonGrid: true,
                gridColor: Color(red: 0.12, green: 0.82, blue: 1.00).opacity(0.20)
            )
        case .girlyVibesDay:
            themedGradient(
                colors: [
                    Color(red: 1.00, green: 0.91, blue: 0.96),
                    Color(red: 0.96, green: 0.84, blue: 1.00),
                    Color(red: 1.00, green: 0.97, blue: 0.91)
                ],
                hasNeonGrid: false,
                gridColor: .clear
            )
        case .girlyVibesNight:
            themedGradient(
                colors: [
                    Color(red: 0.11, green: 0.04, blue: 0.12),
                    Color(red: 0.25, green: 0.08, blue: 0.22),
                    Color(red: 0.08, green: 0.06, blue: 0.18)
                ],
                hasNeonGrid: false,
                gridColor: .clear
            )
        case .chuckNetworkDay:
            themedGradient(
                colors: [
                    Color(red: 0.92, green: 1.00, blue: 0.95),
                    Color(red: 0.80, green: 0.96, blue: 1.00),
                    Color(red: 0.97, green: 1.00, blue: 0.72)
                ],
                hasNeonGrid: true,
                gridColor: Color(red: 0.16, green: 0.84, blue: 0.18).opacity(0.15)
            )
        case .chuckNetworkNight:
            themedGradient(
                colors: [
                    Color(red: 0.01, green: 0.02, blue: 0.02),
                    Color(red: 0.02, green: 0.10, blue: 0.07),
                    Color(red: 0.10, green: 0.04, blue: 0.18)
                ],
                hasNeonGrid: true,
                gridColor: Color(red: 0.28, green: 1.00, blue: 0.25).opacity(0.20)
            )
        }
    }

    private func themedGradient(colors: [Color], hasNeonGrid: Bool, gridColor: Color) -> some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if hasNeonGrid {
                neonGrid(color: gridColor)
            }
        }
    }

    @ViewBuilder
    private func neonGrid(color: Color) -> some View {
#if os(macOS)
        EmptyView()
#else
        Canvas { context, size in
            let spacing: CGFloat = 42
            var x: CGFloat = -spacing
            while x < size.width + spacing {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height * 0.28, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 0.8)
                x += spacing
            }

            var y: CGFloat = 24
            while y < size.height + spacing {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y - size.width * 0.08))
                context.stroke(path, with: .color(color.opacity(0.75)), lineWidth: 0.7)
                y += spacing
            }
        }
#endif
    }

    @ViewBuilder
    private var dayCloudPattern: some View {
#if os(macOS)
        if #available(macOS 12.0, *) {
            dayCloudCanvas
        }
#else
        dayCloudCanvas
#endif
    }

    @ViewBuilder
    private var starPattern: some View {
#if os(macOS)
        if #available(macOS 12.0, *) {
            starCanvas
        }
#else
        starCanvas
#endif
    }

    @ViewBuilder
    private var nightCloudPattern: some View {
#if os(macOS)
        if #available(macOS 12.0, *) {
            nightCloudCanvas
        }
#else
        nightCloudCanvas
#endif
    }

    @ViewBuilder
    private var dayCloudCanvas: some View {
#if os(macOS)
        EmptyView()
#else
        Canvas { context, size in
            for i in 0..<22 {
                let width = size.width * (0.18 + stableUnit(i, salt: 11) * 0.14)
                let height = width * (0.34 + stableUnit(i, salt: 17) * 0.10)
                let x = size.width * stableUnit(i, salt: 23) - width * 0.15
                let y = size.height * stableUnit(i, salt: 31) - height * 0.2
                let cloudRect = CGRect(x: x, y: y, width: width, height: height)
                let cloud = CloudShape().path(in: cloudRect)
                context.fill(cloud, with: .color(Color.white.opacity(0.10 + stableUnit(i, salt: 37) * 0.10)))
            }
        }
#endif
    }

    @ViewBuilder
    private var starCanvas: some View {
#if os(macOS)
        EmptyView()
#else
        Canvas { context, size in
            for i in 0..<64 {
                let x = CGFloat((i * 53) % 1000) / 1000.0 * size.width
                let y = CGFloat((i * 97) % 1000) / 1000.0 * size.height
                let starRect = CGRect(x: x, y: y, width: 1.7, height: 1.7)
                context.fill(Path(ellipseIn: starRect), with: .color(Color.white.opacity(0.65)))
            }
        }
#endif
    }

    private func stableUnit(_ index: Int, salt: Int) -> CGFloat {
        let value = (index * 73 + salt * 193) % 997
        return CGFloat(value) / 997.0
    }

    @ViewBuilder
    private var nightCloudCanvas: some View {
#if os(macOS)
        EmptyView()
#else
        Canvas { context, size in
            for i in 0..<24 {
                let width = size.width * (0.20 + stableUnit(i, salt: 41) * 0.16)
                let height = width * (0.34 + stableUnit(i, salt: 47) * 0.11)
                let x = size.width * stableUnit(i, salt: 53) - width * 0.18
                let y = size.height * stableUnit(i, salt: 59) - height * 0.2
                let cloudRect = CGRect(x: x, y: y, width: width, height: height)
                let cloud = CloudShape().path(in: cloudRect)
                context.fill(cloud, with: .color(Color.black.opacity(0.12 + stableUnit(i, salt: 61) * 0.12)))
                context.stroke(cloud, with: .color(Color.white.opacity(0.04 + stableUnit(i, salt: 67) * 0.06)), lineWidth: 0.7)
            }
        }
#endif
    }
}
