import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openSettings) private var openSettings
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            EgressStatusCard(model: model)

            VStack(spacing: 8) {
                GlassActionButton(
                    title: "立即检测",
                    subtitle: "刷新当前出口身份",
                    systemImage: "arrow.clockwise",
                    tint: .cyan,
                    isDisabled: model.status == .checking,
                    action: model.checkNow
                )

                GlassActionButton(
                    title: model.status == .paused ? "恢复保护" : "暂停保护",
                    subtitle: model.status == .paused ? "重新启用自动检测" : "暂时停止自动处置",
                    systemImage: model.status == .paused ? "play.fill" : "pause.fill",
                    tint: model.status == .paused ? .green : .orange
                ) {
                    model.status == .paused ? model.resumeProtection() : model.pauseProtection()
                }

                GlassActionButton(
                    title: "打开设置",
                    subtitle: "配置规则与受保护应用",
                    systemImage: "slider.horizontal.3",
                    tint: .blue
                ) {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openSettings()
                }

                GlassActionButton(
                    title: "退出 EgressGuard",
                    subtitle: "停止本地出口保护服务",
                    systemImage: "power",
                    tint: .red,
                    showsChevron: false
                ) {
                    model.recordTermination()
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 388)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(MenuGlassPalette.windowTint(colorScheme))
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color.cyan.opacity(0.10), Color.indigo.opacity(0.045), Color.clear]
                        : [Color.white.opacity(0.34), Color.cyan.opacity(0.045), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

private struct EgressStatusCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(model.status.color.opacity(0.13))
                    EgressStatusGlyph(status: model.status, size: 28)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.status.title)
                        .font(.system(size: 15, weight: .semibold))
                    VStack(alignment: .leading, spacing: 3) {
                        ExitAddressLine(label: "代理", identity: model.identity)
                        ExitAddressLine(label: "无代理", identity: model.directIdentity)
                    }
                }
                Spacer()
                if model.hasSplitEgress {
                    Text("分流")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
                Circle()

                    .fill(model.status.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: model.status.color.opacity(0.6), radius: 5)
            }

            if let identity = model.identity {
                Divider().opacity(0.55)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 13) {
                    StatusMetric(label: "国家/地区", value: identity.countryName ?? identity.countryCode ?? "未知")
                    StatusMetric(label: "ASN", value: identity.asn ?? "未知")
                    StatusMetric(label: "数据源", value: identity.provider)
                    StatusMetric(label: "最近检测", value: identity.checkedAt.formatted(date: .omitted, time: .standard))
                }

                if let organization = identity.organization {
                    StatusMetric(label: "运营商", value: organization)
                }
            } else if let error = model.lastErrorMessage {
                Label(error, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let policyMessage = model.policyMessage {
                Label(policyMessage, systemImage: "scope")
                    .font(.caption)
                    .foregroundStyle(model.status == .violation ? .red : .secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MenuGlassPalette.cardTint(colorScheme))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(MenuGlassPalette.border(colorScheme), lineWidth: 0.8)
                }
                .shadow(color: MenuGlassPalette.shadow(colorScheme), radius: 16, y: 7)
        }
    }
}

private struct ExitAddressLine: View {
    let label: String
    let identity: ExitIdentity?

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
            Text(identity?.ipv4Address ?? "未检测到")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.88))
                .textSelection(.enabled)
        }
    }
}

private struct StatusMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GlassActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isDisabled = false
    var showsChevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tint.opacity(0.13))
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13.5, weight: .semibold))
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassButtonStyle(colorScheme: colorScheme))
        .disabled(isDisabled)
    }
}

private struct GlassButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(MenuGlassPalette.buttonTint(colorScheme, isPressed: configuration.isPressed))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(MenuGlassPalette.border(colorScheme), lineWidth: 0.8)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum MenuGlassPalette {
    static func windowTint(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.34) : .white.opacity(0.28)
    }

    static func cardTint(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.22) : .white.opacity(0.24)
    }

    static func buttonTint(_ colorScheme: ColorScheme, isPressed: Bool) -> Color {
        if colorScheme == .dark {
            return .white.opacity(isPressed ? 0.12 : 0.055)
        }
        return .white.opacity(isPressed ? 0.42 : 0.25)
    }

    static func border(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white.opacity(0.13) : .white.opacity(0.72)
    }

    static func shadow(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black.opacity(0.34) : .black.opacity(0.10)
    }
}
