import SwiftUI

struct EgressStatusGlyph: View {
    enum Presentation { case menuBar, interface }

    let status: GuardDisplayStatus
    var size: CGFloat = 20
    var presentation: Presentation = .interface

    private var color: Color { presentation == .menuBar ? .primary : status.color }

    var body: some View {
        ZStack {
            ShieldOutline()
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round))
            Path { path in
                path.move(to: CGPoint(x: size * 0.29, y: size * 0.53))
                path.addLine(to: CGPoint(x: size * 0.71, y: size * 0.53))
                path.move(to: CGPoint(x: size * 0.58, y: size * 0.40))
                path.addLine(to: CGPoint(x: size * 0.72, y: size * 0.53))
                path.addLine(to: CGPoint(x: size * 0.58, y: size * 0.66))
            }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.095, lineCap: .round, lineJoin: .round))
            statusOverlay
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var statusOverlay: some View {
        if presentation == .menuBar {
            menuBarStatusOverlay
        } else {
            detailedStatusOverlay
        }
    }

    @ViewBuilder private var menuBarStatusOverlay: some View {
        switch status {
        case .paused:
            pauseOverlay
        case .suspectedViolation, .violation, .unavailable:
            Image(systemName: "exclamationmark")
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(color).offset(x: size * 0.31, y: -size * 0.28)
        case .starting, .checking, .healthy, .recovering:
            Circle().fill(color).frame(width: size * 0.20, height: size * 0.20)
                .offset(x: size * 0.34, y: -size * 0.31)
        }
    }

    @ViewBuilder private var detailedStatusOverlay: some View {
        switch status {
        case .healthy:
            Circle().fill(color).frame(width: size * 0.20, height: size * 0.20).offset(x: size * 0.34, y: -size * 0.31)
        case .checking, .starting, .recovering:
            Circle().trim(from: 0.12, to: 0.78)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round))
                .frame(width: size * 0.32, height: size * 0.32).offset(x: size * 0.30, y: -size * 0.28)
        case .paused:
            pauseOverlay
        case .suspectedViolation, .unavailable:
            Circle().stroke(color, lineWidth: size * 0.08)
                .frame(width: size * 0.25, height: size * 0.25)
                .overlay(Circle().fill(color).frame(width: size * 0.07, height: size * 0.07))
                .offset(x: size * 0.31, y: -size * 0.29)
        case .violation:
            Image(systemName: "exclamationmark").font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(color).offset(x: size * 0.31, y: -size * 0.28)
        }
    }

    private var pauseOverlay: some View {
        HStack(spacing: size * 0.07) {
            Capsule().fill(color).frame(width: size * 0.07, height: size * 0.23)
            Capsule().fill(color).frame(width: size * 0.07, height: size * 0.23)
        }.offset(x: size * 0.29, y: -size * 0.27)
    }
}

private struct ShieldOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.minY + rect.height * 0.23))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.64))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.04), control: CGPoint(x: rect.maxX - rect.width * 0.25, y: rect.maxY - rect.height * 0.14))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.64), control: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.maxY - rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.23))
        path.closeSubpath()
        return path
    }
}
